package org.testeditor.web.backend.testexecution

import io.dropwizard.testing.ConfigOverride
import io.dropwizard.testing.junit.DropwizardAppRule
import java.io.IOException
import java.net.ServerSocket
import java.util.function.Supplier
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.junit.rules.TestWatcher
import org.junit.runner.Description
import org.slf4j.event.Level
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration
import org.testeditor.web.backend.testexecution.dropwizard.WorkerApplication

import static io.dropwizard.testing.ConfigOverride.config
import static io.dropwizard.testing.ResourceHelpers.resourceFilePath

class TestUtils {

	@FinalFieldsConstructor
	static class BeforeRule extends TestWatcher {

		val ()=>void before

		override protected starting(Description description) {
			before.apply
		}

	}

	@FinalFieldsConstructor
	static class AfterRule extends TestWatcher {

		val ()=>void after

		override protected finished(Description description) {
			after.apply
		}

	}

	def DropwizardAppRule<TestExecutionDropwizardConfiguration> createWorkerRule(Supplier<String> localRepoFileRoot, Supplier<String> remoteRepoUrl,
		Supplier<String> testExecutionManagerUrl, ConfigOverride... overrides) {
		val port = freePort
		return createWorkerRule('worker-config.yml', #[
			config('server.applicationConnectors[0].port', port),
			config('localRepoFileRoot', localRepoFileRoot),
			config('remoteRepoUrl', remoteRepoUrl),
			config('testExecutionManagerUrl', testExecutionManagerUrl),
			config('workerUrl', '''http://localhost:«port»''')
		] + overrides)
	}

	def DropwizardAppRule<TestExecutionDropwizardConfiguration> createWorkerRule(String configFile, ConfigOverride... overrides) {
		return new DropwizardAppRule(WorkerApplication, resourceFilePath(configFile), overrides)
	}

	def ConfigOverride configOverrideLogLevel(Level level) {
		return config('logging.level', level.name)
	}

	def String getFreePort() {
		val socket = new ServerSocket(0)
		val port = socket.localPort.toString
		try {
			socket.close
		} catch (IOException ex) {
		}
		return port
	}

}
