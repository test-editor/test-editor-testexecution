package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.net.URL
import java.util.List
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.FilterRegistration.Dynamic
import javax.ws.rs.core.UriBuilder
import org.testeditor.web.backend.testexecution.TestExecutionExceptionMapper
import org.testeditor.web.backend.testexecution.manager.WorkerClient
import org.testeditor.web.backend.testexecution.worker.TestExecutionManagerClient
import org.testeditor.web.backend.testexecution.worker.WorkerResource
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.EXPOSED_HEADERS_PARAM

class WorkerApplication extends DropwizardApplication<TestExecutionDropwizardConfiguration> {

	@Inject Provider<ExecutionHealthCheck> executionHealthCheckProvider
	@Inject Provider<TestExecutionManagerClient> managerClient


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
			val workerUri = UriBuilder.fromUri(configuration.workerUrl.toURI).path(WorkerResource).build
			
			managerClient.get.registerWorker(new WorkerClient(workerUri))
		]
	}

	override Dynamic configureCorsFilter(TestExecutionDropwizardConfiguration configuration, Environment environment) {
		return super.configureCorsFilter(configuration, environment) => [
			// Configure additional CORS parameters
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location, Location")
		]
	}

}
