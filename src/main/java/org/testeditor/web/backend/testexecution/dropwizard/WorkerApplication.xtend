package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.net.URI
import java.util.List
import java.util.Set
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.FilterRegistration.Dynamic
import javax.ws.rs.core.UriBuilder
import org.eclipse.xtend.lib.annotations.Data
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo
import org.testeditor.web.backend.testexecution.distributed.worker.rest.TestExecutionManagerClient
import org.testeditor.web.backend.testexecution.distributed.worker.rest.WorkerResource
import org.testeditor.web.backend.testexecution.webapi.TestExecutionExceptionMapper
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.EXPOSED_HEADERS_PARAM

class WorkerApplication extends DropwizardApplication<TestExecutionWorkerDropwizardConfiguration> {

	@Inject Provider<ExecutionHealthCheck> executionHealthCheckProvider
	@Inject Provider<TestExecutionManagerClient> managerClient

	@Data
	static class WorkerDescription implements WorkerInfo {
		val URI uri
		val Set<String> providedCapabilities
	}

	def static void main(String[] args) {
		new WorkerApplication().run(args)
	}

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)
		modules += #[new TestExecutionModule, new RestWorkerModule]
	}

	override run(TestExecutionWorkerDropwizardConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)

		environment.jersey => [
			register(TestExecutionExceptionMapper)
			register(WorkerResource)
		]

		environment.healthChecks.register('execution', executionHealthCheckProvider.get)

		environment.lifecycle.addServerLifecycleListener [ server |
			val workerUri = UriBuilder.fromUri(configuration.workerUrl.toURI).path(WorkerResource).build
			
			managerClient.get.registerWorker(new WorkerDescription(workerUri, emptySet))
		]
	}

	override Dynamic configureCorsFilter(TestExecutionWorkerDropwizardConfiguration configuration, Environment environment) {
		return super.configureCorsFilter(configuration, environment) => [
			// Configure additional CORS parameters
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location, Location")
		]
	}

}
