package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.util.List
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.FilterRegistration.Dynamic
import org.glassfish.hk2.utilities.binding.AbstractBinder
import org.glassfish.jersey.process.internal.RequestScoped
import org.testeditor.web.backend.testexecution.distributed.common.RestClient
import org.testeditor.web.backend.testexecution.distributed.manager.rest.TestExecutionManagerExceptionMapper
import org.testeditor.web.backend.testexecution.distributed.manager.rest.TestExecutionManagerResource
import org.testeditor.web.backend.testexecution.util.DefaultUriAppender
import org.testeditor.web.backend.testexecution.util.UriAppender
import org.testeditor.web.backend.testexecution.webapi.TestArtifactResource
import org.testeditor.web.backend.testexecution.webapi.TestExecutionExceptionMapper
import org.testeditor.web.backend.testexecution.webapi.TestSuiteResource
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.EXPOSED_HEADERS_PARAM

class ManagerApplication extends DropwizardApplication<TestExecutionDropwizardConfiguration> {

	@Inject Provider<ExecutionHealthCheck> executionHealthCheckProvider
	@Inject Provider<RestClient> restClient

	def static void main(String[] args) {
		new ManagerApplication().run(args)
	}

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)
		modules += new RestManagerModule
	}

	override run(TestExecutionDropwizardConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)

		environment.jersey => [
			register(TestExecutionExceptionMapper)
			register(TestExecutionManagerExceptionMapper)
			register(TestSuiteResource)
			register(TestArtifactResource)
			register(TestExecutionManagerResource)

			register(new AbstractBinder {

				override protected configure() {
					bind(DefaultUriAppender).proxy(true).proxyForSameScope(false).to(UriAppender).in(RequestScoped)
				}

			})
		]
		environment.objectMapper.injectableValues = new InjectableValueProviderMap(#{'restClient' -> restClient})

		environment.healthChecks.register('execution', executionHealthCheckProvider.get)

	}

	override Dynamic configureCorsFilter(TestExecutionDropwizardConfiguration configuration, Environment environment) {
		return super.configureCorsFilter(configuration, environment) => [
			// Configure additional CORS parameters
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location, Location")
		]
	}

}
