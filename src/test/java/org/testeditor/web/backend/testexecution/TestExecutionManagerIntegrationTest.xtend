package org.testeditor.web.backend.testexecution

import io.dropwizard.testing.ConfigOverride
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PipedInputStream
import java.io.PipedOutputStream
import java.io.PrintStream
import java.util.List
import javax.ws.rs.client.Entity
import javax.ws.rs.core.MediaType
import org.apache.commons.io.output.TeeOutputStream
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.AfterClass
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration
import org.testeditor.web.backend.testexecution.dropwizard.WorkerApplication
import org.testeditor.web.backend.testexecution.worker.WorkerResource

import static io.dropwizard.testing.ConfigOverride.config
import static javax.ws.rs.core.Response.Status.*
import static org.assertj.core.api.Assertions.*
import static java.util.concurrent.CompletableFuture.runAsync
import static java.util.concurrent.TimeUnit.SECONDS

class TestExecutionManagerIntegrationTest extends AbstractIntegrationTest {

	static var PrintStream systemOut
	static val sysioPipe = new PipedInputStream

	@BeforeClass
	def static void setupSystemOut() {
		systemOut = System.out
		val tee = new TeeOutputStream(systemOut, new PipedOutputStream(sysioPipe))
		System.setOut(new PrintStream(tee))
	}

	@AfterClass
	def static void tearDownSystemOut() {
		System.setOut(systemOut)
	}

	@Rule
	public val DropwizardAppRule<TestExecutionDropwizardConfiguration> workerRule = new DropwizardAppRule(
		WorkerApplication,
		ResourceHelpers.resourceFilePath('worker-config.yml'),
		workerConfigs
	)

	protected def List<ConfigOverride> getWorkerConfigs() {
		return #[
			config('server.applicationConnectors[0].port', '0'),
			config('localRepoFileRoot', workspaceRoot.root.path),
			config('remoteRepoUrl', setupRemoteGitRepository),
			config('testExecutionManagerUrl', '''http://localhost:«serverPort»/testexecution/manager/workers''')
		]
	}

	@Test(timeout=5000)
	def void workerRegistersWithManagerAtStartup() {
		val expectedLogLine = '''«WorkerResource.name»: successfully registered at "http://localhost:«serverPort»/testexecution/manager/workers/http%3A%2F%2Flocalhost%3A«workerRule.localPort»%2Fworker%2Fjob"'''

		val sysioReader = new BufferedReader(new InputStreamReader(sysioPipe))
		sysioReader.lines.takeWhile[!contains('stopped')].anyMatch[contains(expectedLogLine)].assertTrue
	}

	@Test()
	def void jobIsAssignedToWorker() {
		// given
		waitForWorkerRegistration
		
		val workspaceRootPath = workspaceRoot.root.toPath
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "Hello stdout!"
				echo "test was run" > test.ok.txt
			''')
			commitInRemoteRepository
		]
		println('remote git folder: ' + remoteGitFolder.root.absolutePath)

		// when
		val request = createLaunchNewRequest().buildPost(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		val response = request.submit.get
		println('received response')
		Thread.sleep(200)
//		
//		// then
//		println('thread woke up')
//		assertThat(response.status).isEqualTo(CREATED.statusCode)
//		assertThat(response.headers.get("Location").toString).matches("\\[http://localhost:[0-9]+/test-suite/0/0\\]")
//		
//		println('assertions went through...')
//
//		createTestRequest(TestExecutionKey.valueOf('0-0')).get // wait for test to terminate
//		println('test terminated (apparantly...)')
//		val executionResult = workspaceRootPath.resolve('test.ok.txt').toFile
//		assertThat(executionResult).exists
//		
//		println('end of test')

	}

	private def void waitForWorkerRegistration() {
		runAsync[
			val expectedLogLine = '''«WorkerResource.name»: successfully registered at "http://localhost:«serverPort»/testexecution/manager/workers/http%3A%2F%2Flocalhost%3A«workerRule.localPort»%2Fworker%2Fjob"'''

			val sysioReader = new BufferedReader(new InputStreamReader(sysioPipe))
			sysioReader.lines.anyMatch[contains(expectedLogLine)]
		].get(5, SECONDS)
	}

}
