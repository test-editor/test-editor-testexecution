package org.testeditor.web.backend.testexecution

import io.dropwizard.testing.ConfigOverride
import io.dropwizard.testing.junit.DropwizardAppRule
import java.io.IOException
import java.io.PipedInputStream
import java.io.PipedOutputStream
import java.io.PrintStream
import java.net.ServerSocket
import org.apache.commons.io.output.TeeOutputStream
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Delegate
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.junit.rules.RuleChain
import org.junit.rules.TestRule
import org.junit.rules.TestWatcher
import org.junit.runner.Description
import org.slf4j.event.Level
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration
import org.testeditor.web.backend.testexecution.dropwizard.WorkerApplication

import static io.dropwizard.testing.ConfigOverride.config
import static io.dropwizard.testing.ResourceHelpers.resourceFilePath

class TestUtils {

	@Accessors
	static class SysIoPipeRule extends TestWatcher {

		val PrintStream systemOut = System.out
		val PipedInputStream sysioPipe = new PipedInputStream

		override protected starting(Description description) {
			val tee = new TeeOutputStream(systemOut, new PipedOutputStream(sysioPipe))
			System.setOut(new PrintStream(tee))
		}

	}

	@FinalFieldsConstructor
	static class SysIoPipeCloseAndRestoreRule extends TestWatcher {

		val PipedInputStream sysioPipe
		val PrintStream systemOut

		override protected finished(Description description) {
			sysioPipe.close
			System.setOut(systemOut)
		}

	}

	static class SysIoPipeRuleChain implements TestRule {

		@Delegate
		val RuleChain ruleChain
		@Accessors
		val SysIoPipeRule sysIoPipeRule

		new(TestRule... innerRules) {
			sysIoPipeRule = new SysIoPipeRule
			ruleChain = innerRules.fold(RuleChain.outerRule(sysIoPipeRule)) [ RuleChain chain, TestRule innerRule |
				chain.around(innerRule)
			].around(new SysIoPipeCloseAndRestoreRule(sysIoPipeRule.sysioPipe, sysIoPipeRule.systemOut))
		}

	}

	def DropwizardAppRule<TestExecutionDropwizardConfiguration> createWorkerRule(String localRepoFileRoot, String remoteRepoUrl, String testExecutionManagerUrl, ConfigOverride... overrides) {
		return createWorkerRule('worker-config.yml', #[
			config('server.applicationConnectors[0].port', '0'),
			config('localRepoFileRoot', localRepoFileRoot),
			config('remoteRepoUrl', remoteRepoUrl),
			config('testExecutionManagerUrl', testExecutionManagerUrl)			
		] + overrides)
	}

	def DropwizardAppRule<TestExecutionDropwizardConfiguration> createWorkerRule(ConfigOverride... overrides) {
		return createWorkerRule('worker-config.yml', overrides)
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
