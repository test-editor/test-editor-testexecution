package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.AbstractModule
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
import org.glassfish.hk2.utilities.binding.AbstractBinder
import org.glassfish.jersey.process.internal.RequestScoped
import org.testeditor.web.backend.testexecution.TestExecutionExceptionMapper
import org.testeditor.web.backend.testexecution.TestSuiteResource
import org.testeditor.web.backend.testexecution.manager.DefaultUriAppender
import org.testeditor.web.backend.testexecution.manager.TestExecutionManagerExceptionMapper
import org.testeditor.web.backend.testexecution.manager.UriAppender
import org.testeditor.web.backend.testexecution.manager.WorkersResource
import org.testeditor.web.dropwizard.DropwizardApplication

import static org.eclipse.jetty.servlets.CrossOriginFilter.EXPOSED_HEADERS_PARAM

class TestExecutionApplication extends DropwizardApplication<TestExecutionDropwizardConfiguration> {

	@Inject Provider<ExecutionHealthCheck> executionHealthCheckProvider
	@Inject Provider<RestClient> restClient
//	@Inject Provider<UriInfo> uriInfoProvider

	def static void main(String[] args) {
		new TestExecutionApplication().run(args)
	}

	override protected collectModules(List<Module> modules) {
		super.collectModules(modules)
		modules += new TestExecutionModule
		modules += new AbstractModule {
			override configure() {
//				bind(UriAppender).toProvider(UriAppenderProvider).in(ServletScopes.REQUEST)
//				bind(UriAppender).to(DefaultUriAppender).in(ServletScopes.REQUEST)
			}

//			@Provides
//			def UriInfo provideUriInfo() {
//				return uriInfoProvider.get
//			}
		}
	}

	override run(TestExecutionDropwizardConfiguration configuration, Environment environment) throws Exception {
		super.run(configuration, environment)

		environment.jersey => [
			register(TestExecutionExceptionMapper)
			register(TestExecutionManagerExceptionMapper)
			register(TestSuiteResource)
			register(TestArtifactResource)
			register(WorkersResource)
			
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

//class UriAppenderProvider implements Provider<UriAppender> {
//	@Inject
//	Provider<UriInfo> uriInfoProvider
//	
//	override get() {
//		return new DefaultUriAppender(uriInfoProvider.get)
//	}
//	
//}
