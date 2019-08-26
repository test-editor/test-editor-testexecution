package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.net.URL
import java.util.List
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.FilterRegistration.Dynamic
import javax.ws.rs.core.Response.Status
import javax.ws.rs.core.UriBuilder
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionExceptionMapper
import org.testeditor.web.backend.testexecution.worker.Worker
import org.testeditor.web.backend.testexecution.worker.WorkerResource
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.EXPOSED_HEADERS_PARAM

class WorkerApplication extends DropwizardApplication<TestExecutionDropwizardConfiguration> {

	static val logger = LoggerFactory.getLogger(WorkerResource)

	@Inject Provider<ExecutionHealthCheck> executionHealthCheckProvider
	@Inject Provider<RestClient> client

	val registrationScheduler = Executors.newSingleThreadScheduledExecutor
	var ScheduledFuture<?> registrationTask
	var registrationRetries = 0

	def static void main(String[] args) {
		new WorkerApplication().run(args)
	}

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)
		modules += new TestExecutionModule
	}

	override run(TestExecutionDropwizardConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)

		environment.jersey => [
			register(TestExecutionExceptionMapper)
			register(WorkerResource)
		]

		environment.healthChecks.register('execution', executionHealthCheckProvider.get)

		environment.lifecycle.addServerLifecycleListener [ server |
			registrationTask = registrationScheduler.scheduleWithFixedDelay([tryRegistration(configuration, server.URI.port)], 0,
				configuration.registrationRetryIntervalSecs, TimeUnit.SECONDS)
		]
	}

	private def void tryRegistration(TestExecutionDropwizardConfiguration config, int serverPort) {
		val jobResourcePath = UriBuilder.fromResource(WorkerResource).path('job').build.toString
		val workerUri = new URL(config.workerUrl.protocol, config.workerUrl.host, serverPort, jobResourcePath).toURI
//		val workerUri = uriInfo.get.baseUriBuilder.path(WorkerResource).path('job').build
		if (registrationRetries++ < config.registrationMaxRetries) {
			logger.info('''trying to register with test execution manager at "«config.testExecutionManagerUrl»"''')
			val response = client.get.postAsync(config.testExecutionManagerUrl, new Worker => [uri = workerUri]).toCompletableFuture.join
			if (response.statusInfo == Status.CREATED) {
				logger.info('''successfully registered at "«response.location.toString»"''')
				registrationTask.cancel(false)
			} else if (response.statusInfo == Status.CONFLICT) {
				val message = response.readEntity(String)
				logger.warn('''test execution manager already has a worker registered at "«workerUri»"; message: «message»''')
				registrationTask.cancel(false)
			} else {
				logger.warn('''registration with test execution manager failed, retry in «config.registrationRetryIntervalSecs» seconds''')
			}
		} else {
			logger.warn('''giving up registering with test execution manager after «registrationRetries» attempts''')
			registrationTask.cancel(false)
		}
	}

	override Dynamic configureCorsFilter(TestExecutionDropwizardConfiguration configuration, Environment environment) {
		return super.configureCorsFilter(configuration, environment) => [
			// Configure additional CORS parameters
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location, Location")
		]
	}

}
