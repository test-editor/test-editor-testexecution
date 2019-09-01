package org.testeditor.web.backend.testexecution

import java.io.BufferedReader
import java.io.InputStreamReader
import javax.ws.rs.client.Entity
import javax.ws.rs.core.MediaType
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Rule
import org.junit.Test
import org.testeditor.web.backend.testexecution.TestUtils.SysIoPipeRuleChain
import org.testeditor.web.backend.testexecution.worker.WorkerResource

import static javax.ws.rs.core.Response.Status.CREATED
import static org.assertj.core.api.Assertions.*

class TestExecutionManagerIntegrationTest extends AbstractIntegrationTest {

	val workerRule = createWorkerRule(
		workspaceRoot.root.path,
		setupRemoteGitRepository,
		'''http://localhost:«serverPort»/testexecution/manager/workers'''
	)

	@Rule
	public val extension SysIoPipeRuleChain = new SysIoPipeRuleChain(dropwizardAppRule, workerRule)

	@Test(timeout=5000)
	def void workerRegistersWithManagerAtStartup() {
		val expectedLogLine = '''«WorkerResource.name»: successfully registered at "http://localhost:«serverPort»/testexecution/manager/workers/http%3A%2F%2Flocalhost%3A«workerRule.localPort»%2Fworker"'''

		val sysioReader = new BufferedReader(new InputStreamReader(sysIoPipeRule.sysioPipe))
		sysioReader.lines.takeWhile[!contains('stopped')].anyMatch[contains(expectedLogLine)].assertTrue
	}

	@Test
	def void jobIsAssignedToWorker() {
		// given
		waitForLogLine('''«WorkerResource.name»: successfully registered at "http://localhost:«serverPort»/testexecution/manager/workers/http%3A%2F%2Flocalhost%3A«workerRule.localPort»%2Fworker"''')

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

		// when
		val request = createLaunchNewRequest().buildPost(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(CREATED.statusCode)
		assertThat(response.headers.get("Location").toString).matches("\\[http://localhost:[0-9]+/test-suite/0/0\\]")

		val statusResponse = createTestRequest(TestExecutionKey.valueOf('0-0')).get // wait for test to terminate
		val status = statusResponse.readEntity(String)
		val executionResult = workspaceRootPath.resolve('test.ok.txt').toFile
		assertThat(status).isEqualTo('SUCCESS')
		assertThat(executionResult).exists

	}

}
