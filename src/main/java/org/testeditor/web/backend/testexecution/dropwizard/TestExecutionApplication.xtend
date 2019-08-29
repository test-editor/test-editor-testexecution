package org.testeditor.web.backend.testexecution.dropwizard

import com.fasterxml.jackson.databind.BeanProperty
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.InjectableValues
import com.fasterxml.jackson.databind.JsonMappingException
import com.google.inject.Module
import io.dropwizard.setup.Environment
import java.util.List
import javax.inject.Inject
import javax.inject.Provider
import javax.servlet.FilterRegistration.Dynamic
import io.dropwizard.client.JerseyClientBuilder
import org.glassfish.jersey.client.rx.RxClient
import org.glassfish.jersey.client.rx.java8.RxCompletionStageInvoker
import org.testeditor.web.backend.testexecution.TestArtifactResource
import org.testeditor.web.backend.testexecution.TestExecutionExceptionMapper
import org.testeditor.web.backend.testexecution.TestSuiteResource
import org.testeditor.web.backend.testexecution.manager.WorkersResource
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.EXPOSED_HEADERS_PARAM

class TestExecutionApplication extends DropwizardApplication<TestExecutionDropwizardConfiguration> {

	@Inject Provider<ExecutionHealthCheck> executionHealthCheckProvider
	@Inject Provider<RestClient> restClient

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
			register(WorkersResource)
		]
		environment.objectMapper.injectableValues = new InjectableValues {

			val values = #{'restClient' -> restClient}

			override findInjectableValue(Object valueId, DeserializationContext ctxt, BeanProperty forProperty,
				Object beanInstance) throws JsonMappingException {
				return values.get(valueId)?.get
			}

		}
		environment.healthChecks.register('execution', executionHealthCheckProvider.get)

	}

	override Dynamic configureCorsFilter(TestExecutionDropwizardConfiguration configuration, Environment environment) {
		return super.configureCorsFilter(configuration, environment) => [
			// Configure additional CORS parameters
			setInitParameter(EXPOSED_HEADERS_PARAM, "Content-Location, Location")
		]
	}

}
