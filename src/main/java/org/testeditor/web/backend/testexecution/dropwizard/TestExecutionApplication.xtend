package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.util.List
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.FilterRegistration.Dynamic
import org.testeditor.web.backend.testexecution.TestArtifactResource
import org.testeditor.web.backend.testexecution.TestExecutionExceptionMapper
import org.testeditor.web.backend.testexecution.TestSuiteResource
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.EXPOSED_HEADERS_PARAM

class TestExecutionApplication extends DropwizardApplication<TestExecutionDropwizardConfiguration> {
	
	@Inject Provider<ExecutionHealthCheck> executionHealthCheckProvider
	
	def static void main(String[] args) {
		new TestExecutionApplication().run(args)
	}

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)
		modules += new TestExecutionModule
	}

	override run(TestExecutionDropwizardConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)
		environment.jersey => [
			register(TestExecutionExceptionMapper)
			register(TestSuiteResource)
			register(TestArtifactResource)
		]

		environment.healthChecks.register('execution', executionHealthCheckProvider.get)
	}

	override Dynamic configureCorsFilter(TestExecutionDropwizardConfiguration configuration, Environment environment) {
		return super.configureCorsFilter(configuration, environment) => [
			// Configure additional CORS parameters
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location, Location")
		]
	}
}
