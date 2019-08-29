package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.AbstractModule
import com.google.inject.Provides
import io.dropwizard.client.JerseyClientBuilder
import io.dropwizard.setup.Environment
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.ForkJoinPool
import org.glassfish.jersey.client.rx.RxClient
import org.glassfish.jersey.client.rx.java8.RxCompletionStageInvoker
import org.glassfish.jersey.logging.LoggingFeature
import org.testeditor.web.backend.testexecution.TestStatusMapper
import org.testeditor.web.backend.testexecution.loglines.Log4JDefaultFilter
import org.testeditor.web.backend.testexecution.loglines.LogFilter
import org.testeditor.web.backend.testexecution.loglines.LogFinder
import org.testeditor.web.backend.testexecution.loglines.ScanningLogFinder
import org.testeditor.web.backend.testexecution.manager.TestStatusManager
import org.testeditor.web.backend.testexecution.screenshots.ScreenshotFinder
import org.testeditor.web.backend.testexecution.screenshots.SubStepAggregatingScreenshotFinder
import org.testeditor.web.backend.testexecution.util.HierarchicalLineSkipper
import org.testeditor.web.backend.testexecution.util.RecursiveHierarchicalLineSkipper
import org.testeditor.web.backend.testexecution.workspace.WorkspaceProvider

import static com.google.inject.name.Names.named

class TestExecutionModule extends AbstractModule {

	var RxClient<RxCompletionStageInvoker> rxClient = null

	override protected configure() {
		binder => [
			bind(Executor).toInstance(ForkJoinPool.commonPool)
			bind(Executor).annotatedWith(named("TestExecutionManagerExecutor")).toInstance(ForkJoinPool.commonPool)
			bind(ScreenshotFinder).to(SubStepAggregatingScreenshotFinder)
			bind(LogFinder).to(ScanningLogFinder)
			bind(HierarchicalLineSkipper).to(RecursiveHierarchicalLineSkipper)
			bind(LogFilter).to(Log4JDefaultFilter)
			bind(File).annotatedWith(named("workspace")).toProvider(WorkspaceProvider)
			bind(TestExecutionConfiguration).to(TestExecutionDropwizardConfiguration)
			bind(GitConfiguration).to(TestExecutionDropwizardConfiguration)
			bind(RestClient).to(JerseyBasedRestClient)
			bind(TestStatusMapper).to(TestStatusManager)
		]
	}

	/**
	 * This provider method is needed because ProcessBuilder has no standard
	 * constructor. The method actually calls a constructor that takes a varargs
	 * parameter of type String, and implicitly passes an empty array.
	 */
	@Provides
	def ProcessBuilder provideProcessBuilder() {
		return new ProcessBuilder
	}

	@Provides
	def RxClient<RxCompletionStageInvoker> provideRxClient(TestExecutionDropwizardConfiguration configuration, Environment environment) {
		if (rxClient === null) {
			rxClient = new JerseyClientBuilder(environment) //
			.using(configuration.jerseyClientConfiguration) //
			.withProperty(LoggingFeature.LOGGING_FEATURE_VERBOSITY_CLIENT, LoggingFeature.Verbosity.PAYLOAD_TEXT) //
			.buildRx(TestExecutionApplication.simpleName, RxCompletionStageInvoker)
		}
		return rxClient
	}

}
