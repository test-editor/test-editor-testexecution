package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.core.JsonFactory
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.node.JsonNodeType
import java.io.File
import java.util.List
import java.util.Map
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern
import javax.ws.rs.client.Entity
import javax.ws.rs.core.GenericType
import javax.ws.rs.core.MediaType
import org.assertj.core.api.SoftAssertions
import org.eclipse.jgit.junit.JGitTestUtil
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain

import static java.nio.charset.StandardCharsets.UTF_8
import static javax.ws.rs.core.Response.Status.*
import static org.assertj.core.api.Assertions.*

import static extension org.apache.commons.io.FileUtils.writeStringToFile

//@Ignore('temporarily ignored as the worker infrastructure introduced very deep changes; these tests may have to be recreated from scratch')
class TestSuiteExecutorIntegrationTest extends AbstractIntegrationTest {

	val workerRule = createWorkerRule(
		[workerWorkspace.root.path],
		[setupRemoteGitRepository],
		['''http://localhost:«serverPort»/testexecution/manager/workers''']
	)

	@Rule
	public val extension RuleChain = RuleChain.outerRule(remoteGitFolder).around(managerWorkspace).around(workerWorkspace).around(dropwizardAppRule).around(workerRule)
	
	@Before
	def void waitForWorkerRegistration() {
		var retries = 0
		var isRegistered = false
		do {
			Thread.sleep(2000)
			val request = createRequest('worker/registered', workerRule)
			assertThat(request).isNotNull
			val response = request.get
			isRegistered = response.readEntity(Boolean)
			retries++
		} while (!isRegistered && retries < 3)
		assertThat(isRegistered).^as('worker registration').isTrue
	}

	@Test
	def void testThatCallTreeIsNotFoundIfNotExistent() {
		remoteGitFolder.newFile('SomeTest.tcl').commitInRemoteRepository
		remoteGitFolder.newFolder(TestExecutorProvider.LOG_FOLDER)
		remoteGitFolder.newFile(TestExecutorProvider.LOG_FOLDER + '/testrun.1-1--.200001011200123.yaml').commitInRemoteRepository

		// when
		val response = createCallTreeRequest(TestExecutionKey.valueOf('1-2')).get

		// then
		assertThat(response.status).isEqualTo(NOT_FOUND.statusCode)
	}

	@Test
	def void testThatCallTreeOfLastRunReturnsLatestJson() {
		// given
		val mapper = new ObjectMapper(new JsonFactory)
		managerWorkspace.newFolder(TestExecutorProvider.LOG_FOLDER)
		// latest (12 o'clock)
		val latestCommitID = 'abcd'
		val previousCommitID = '1234'
		managerWorkspace.newFile(TestExecutorProvider.LOG_FOLDER + '/testrun.0-0--.200001011200123.yaml') => [
			writeStringToFile('''
				"started": "on some instant"
				"resourcePaths": [ "o'ne/two/three", "two/three.tcl" ]
				"testRuns":
				- "source": "SomeTest"
				  "commitId": "«latestCommitID»"
				  "children":
			''', UTF_8)
		]
		// previous (11 o'clock)
		managerWorkspace.newFile(TestExecutorProvider.LOG_FOLDER + '/testrun.0-0--.200001011100123.yaml') => [
			writeStringToFile('''
				"started": "on some instant"
				"resourcePaths": [ "one", "two" ]
				"testRuns":
				- "source": "SomeTest"
				  "commitId": "«previousCommitID»"
				  "children":
			''', UTF_8)
		]

		// when
		val request = createCallTreeRequest(TestExecutionKey.valueOf('0-0')).buildGet
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(OK.statusCode)

		val jsonString = response.readEntity(String)
		val json = mapper.readTree(jsonString)
		val jsonNode = json.get('testRuns').get(0)
		assertThat(jsonNode.get('source').asText).isEqualTo('SomeTest')
		assertThat(jsonNode.get('commitId').asText).isEqualTo(latestCommitID)
		assertThat(json.get('resourcePaths').get(0).asText).isEqualTo("o'ne/two/three")
	}

	@Test
	def void testThatCallTreeOfLastRunReturnsExpectedJSON() {
		// given
		val mapper = new ObjectMapper(new JsonFactory)
		remoteGitFolder.newFile('SomeTest.tcl').commitInRemoteRepository
		managerWorkspace.newFolder(TestExecutorProvider.LOG_FOLDER)
		managerWorkspace.newFile(TestExecutorProvider.LOG_FOLDER + '/testrun.0-0--.200001011200123.yaml') => [
			writeStringToFile('''
				"started": "on some instant"
				"resourcePaths": [ "one", "two" ]
				"testRuns":
				- "source": "SomeTest"
				  "commitId": 
				  "children":
				  - "node": "Test"
				    "message": "test"
				    "id": 4711
				    "preVariables":
				    - { "b": "7" }
				    - { "c[1].\"key with spaces\"": "5" }
				    "children":
				    "status": "OK"
				    "postVariables":
				    - { "a": "some" }
			''', UTF_8)
			
		]

		// when
		val request = createCallTreeRequest(TestExecutionKey.valueOf('0-0')).buildGet
		val response = request.submit.get

		// then
		assertThat(response.status).isEqualTo(OK.statusCode)

		val jsonString = response.readEntity(String)
		val jsonNode = mapper.readTree(jsonString).get('testRuns').get(0)
		assertThat(jsonNode.get('source').asText).isEqualTo('SomeTest')
		jsonNode.get('children') => [
			assertThat(nodeType).isEqualTo(JsonNodeType.ARRAY)
			assertThat(size).isEqualTo(1)
			get(0) => [
				assertThat(get('status').asText).isEqualTo('OK')
				get('preVariables') => [
					assertThat(nodeType).isEqualTo(JsonNodeType.ARRAY)
					assertThat(size).isEqualTo(2)
					assertThat(get(1).fields.head.key).isEqualTo('c[1]."key with spaces"')
					assertThat(get(1).fields.head.value.asText).isEqualTo('5')
				]
			]
		]
	}

	@Test
	def void testThatTestexecutionIsInvoked() {
		// given
		val workspaceRootPath = workerWorkspace.root.toPath
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

		createTestRequest(TestExecutionKey.valueOf('0-0')).get // wait for test to terminate
		val executionResult = workspaceRootPath.resolve('test.ok.txt').toFile
		assertThat(executionResult).exists
	}

	@Test
	def void testThatRunningsReturned() {
		// given
		val jobId = TestExecutionKey.valueOf('0-0')
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				sleep 30 # ensure test reads process's status while still running
				echo "test was run" > test.ok.txt
			''')
			commitInRemoteRepository
		]
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		assertThat(response.status).isEqualTo(CREATED.statusCode)
		val waitForStatus = createTestRequest(jobId).get.readEntity(String) // give the worker time to assign and start executing the test
		assertThat(waitForStatus).^as('status after having waited').isEqualTo('RUNNING')

		// when
		val actualTestStatus = createAsyncTestRequest(jobId).get

		// then
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('RUNNING')

	}

	@Test
	def void testThatSuccessIsReturned() {
		// given
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "test was run" > test.ok.txt
			''')
			commitInRemoteRepository
		]
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		assertThat(response.status).isEqualTo(CREATED.statusCode)

		// when
		val actualTestStatus = createTestRequest(TestExecutionKey.valueOf('0-0')).get

		// then
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('SUCCESS')

	}

	@Test
	def void testThatFailuresReturned() {
		// given
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				exit 1 # signal error/failure
			''')
			commitInRemoteRepository
		]
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		assertThat(response.status).isEqualTo(CREATED.statusCode)

		// when
		val actualTestStatus = createTestRequest(TestExecutionKey.valueOf('0-0')).get

		// then
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('FAILED')

	}

	@Test
	def void testThatNodeDetailsAreProvided() {
		val testKey = TestExecutionKey.valueOf('1-5')
		managerWorkspace.newFolder('logs')
		managerWorkspace.newFile('''logs/testrun.«testKey».200000000000.yaml''') => [
			executable = true
			writeStringToFile('''
				"testRuns":
				- "source": "test.tcl"
				  "testRunId": "1"
				  "children" :
				  - "node": "TEST"
				    "id": "ID1"
				    "children":
				    - "node": "SPECIFICATION"
				      "id": "ID2"
				      "message": "hello"
				      "children":
				      - "id": "IDXY"
				      - "id": "IDXZ"
				      - "id": "IDYZ"
				    - "node": "SPECIFICATION"
				      "id": "ID3"
			''', UTF_8)
		]
		managerWorkspace.newFile('''logs/testrun.«testKey».200000000000.log''')

		// when
		val result = createNodeRequest(testKey.deriveWithCaseRunId('1').deriveWithCallTreeId('ID2')).get.readEntity(String)

		// then
		val properties = new ObjectMapper().readValue(result, Object).assertInstanceOf(List).findFirst [ map |
			"properties".equals((map as Map<String, Object>).get("type"))
		].assertInstanceOf(Map)
		val propertiesContent = properties.get("content").assertInstanceOf(Map)
		propertiesContent.get("id").assertEquals("ID2")
		propertiesContent.get("message").assertEquals("hello")

	}

	@Test
	def void testThatRootNodesWrittenAfterTestTerminates() {
		// given
		val mapper = new ObjectMapper(new JsonFactory)
		val testKey = TestExecutionKey.valueOf('0-0')
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFolder('logs')
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "Dummy test execution"
			''')
			commitInRemoteRepository
		]

		val launchResponse = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		launchResponse.status.assertEquals(CREATED.statusCode)
		createTestRequest(testKey).get // wait for completion
		// when
		val jsonString = createCallTreeRequest(testKey).buildGet.submit.get.readEntity(String)

		// then
		val overallTestStatus = mapper.readTree(jsonString).get('status').asText
		assertThat(overallTestStatus).isEqualTo('SUCCESS')
	}

	@Test
	def void testThatScreenshotDetailsAreProvided() {
		val testKey = TestExecutionKey.valueOf('0-0')
		val screenshotPath = 'screenshots/test/hello.png'
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFolder('logs')
		remoteGitFolder.newFile('''logs/testrun.«testKey».299900000000.yaml''') => [
			executable = true
			JGitTestUtil.write(it, '''
				"testRuns":
				- "source": "test.tcl"
				  "testRunId": "1"
				  "children" :
				  - "node": "TEST"
				    "id": "ID1"
				    "children":
				    - "node": "SPECIFICATION"
				      "id": "ID2"
				      "message": "hello"
				      "children":
				      - "id": "IDXY"
				      - "id": "IDXZ"
				      - "id": "IDYZ"
				    - "node": "SPECIFICATION"
				      "id": "ID3"
			''')
			commitInRemoteRepository
		]
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "Running mock gradlew script from working directory $(pwd)"
				set -x
				targetDir=".testexecution/artifacts/«testKey.suiteId»/«testKey.suiteRunId»/1"
				mkdir -p ${targetDir}
				printf '"screenshot": "«screenshotPath»"\n' > ${targetDir}/ID2.yaml
			''')
			commitInRemoteRepository
		]

		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		response.status.assertEquals(CREATED.statusCode)
		createTestRequest(testKey).get // wait for completion
		new File(managerWorkspace.root, '.testexecution/artifacts/0/0/1/ID2.yaml').exists.assertTrue(
			'Mocked process did not write yaml file with screenshot information.')

		// when
		val result = createNodeRequest(testKey.deriveWithCaseRunId("1").deriveWithCallTreeId('ID2')).get.readEntity(String)

		// then
		val properties = new ObjectMapper().readValue(result, Object).assertInstanceOf(List).findFirst [ map |
			"image".equals((map as Map<String, Object>).get("type"))
		].assertInstanceOf(Map)
		properties.get("content").assertInstanceOf(String).assertEquals(screenshotPath)

	}

	@Test
	def void testThatSubStepScreenshotDetailsAreProvided() {
		val testKey = TestExecutionKey.valueOf('0-0')
		val childKeys = #['IDXY', 'IDXZ', 'IDYZ']
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFolder('logs')
		remoteGitFolder.newFile('''logs/testrun.«testKey».299900000000.yaml''') => [
			executable = true
			JGitTestUtil.write(it, '''
				"testRuns":
				- "source": "test.tcl"
				  "testRunId": "1"
				  "children" :
				  - "node": "TEST"
				    "id": "ID1"
				    "children":
				    - "node": "SPECIFICATION"
				      "id": "ID2"
				      "message": "hello"
				      "children":
				      - "id": "IDXY"
				      - "id": "IDXZ"
				      - "id": "IDYZ"
				    - "node": "SPECIFICATION"
				      "id": "ID3"
			''')
			commitInRemoteRepository
		]
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "Running mock gradlew script from working directory $(pwd)"
				set -x
				targetDir=".testexecution/artifacts/«testKey.suiteId»/«testKey.suiteRunId»/1"
				mkdir -p ${targetDir}
				«FOR id : childKeys»
					printf '"screenshot": "screenshots/test/«id».png"\n' > ${targetDir}/«id».yaml
				«ENDFOR»
			''')
			commitInRemoteRepository
		]

		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		response.status.assertEquals(CREATED.statusCode)
		createTestRequest(testKey).get // wait for completion
		childKeys.forall[new File(managerWorkspace.root, '''.testexecution/artifacts/0/0/1/«it».yaml''').exists].assertTrue(
			'Mocked process did not write yaml file with screenshot information.')

		// when
		val result = createNodeRequest(testKey.deriveWithCaseRunId("1").deriveWithCallTreeId('ID2')).get.readEntity(String)

		// then
		val propertiesList = newArrayList
		propertiesList.addAll(new ObjectMapper().readValue(result, Object).assertInstanceOf(List).filter [ map |
			'image'.equals((map as Map<String, Object>).get('type'))
		].assertSize(3))

		propertiesList.get(0).assertInstanceOf(Map).get('content').assertInstanceOf(String).assertEquals('screenshots/test/IDXY.png')
		propertiesList.get(1).assertInstanceOf(Map).get('content').assertInstanceOf(String).assertEquals('screenshots/test/IDXZ.png')
		propertiesList.get(2).assertInstanceOf(Map).get('content').assertInstanceOf(String).assertEquals('screenshots/test/IDYZ.png')

	}

	@Test
	def void testThatLogLinesAreProvided() {
		val testKey = TestExecutionKey.valueOf('0-0')
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFolder('logs')
		remoteGitFolder.newFile('''logs/testrun.«testKey».299900000000.yaml''') => [
			executable = true
			JGitTestUtil.write(it, '''
				"testRuns":
				- "source": "test.tcl"
				  "testRunId": "1"
				  "children" :
				  - "node": "TEST"
				    "id": "ID1"
				    "children":
				    - "node": "SPECIFICATION"
				      "id": "ID2"
				      "message": "hello"
				      "children":
				      - "id": "IDXY"
				      - "id": "IDXZ"
				      - "id": "IDYZ"
				    - "node": "SPECIFICATION"
				      "id": "ID9"
			''')
			commitInRemoteRepository
		]
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo ">>>>>>>>>>>>>>>> got the following test class: org.testeditor.Minimal with id 1.5.1"
				echo "@TESTRUN:ENTER:0.0.1"
				echo ""
				echo "org.testeditor.Minimal > execute STANDARD_OUT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:ENTER:2e86865c:IDROOT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Running test for org.testeditor.Minimal"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:ENTER:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:ENTER:f960cf39:ID2"
				(>&2 echo "Test message to standard error")
				echo "  some regular message"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:ENTER:c8b68596:ID3"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:ENTER:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:ENTER:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:ENTER:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:ENTER:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:ENTER:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:ENTER:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:LEAVE:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:LEAVE:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:LEAVE:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:LEAVE:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:LEAVE:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:LEAVE:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:LEAVE:c8b68596:ID3"
				echo "   tailing output"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:LEAVE:f960cf39:ID2"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:LEAVE:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Test org.testeditor.Minimal finished with 0 sec. duration."
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:LEAVE:2e86865c:IDROOT"
				echo "@TESTRUN:LEAVE:0.0.1"
			''')
			commitInRemoteRepository
		]

		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		response.status.assertEquals(CREATED.statusCode)
		createTestRequest(testKey).get // wait for completion
		// when
		val result = createNodeRequest(testKey.deriveWithCaseRunId("1").deriveWithCallTreeId('ID9')).get.readEntity(String)

		// then
		val properties = new ObjectMapper().readValue(result, Object).assertInstanceOf(List).findFirst [ map |
			"text".equals((map as Map<String, Object>).get("type"))
		].assertInstanceOf(Map)
		properties.get("content").assertInstanceOf(List).assertEquals(
			#['    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)'])

	}

	@Test
	def void testThatLogLinesAreFilteredToTheSpecifiedLogLevel() {
		val testKey = TestExecutionKey.valueOf('0-0')
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFolder('logs')
		remoteGitFolder.newFile('''logs/testrun.«testKey».299900000000.yaml''') => [
			executable = true
			JGitTestUtil.write(it, '''
				"testRuns":
				- "source": "test.tcl"
				  "testRunId": "1"
				  "children" :
				  - "node": "TEST"
				    "id": "ID1"
				    "children":
				    - "node": "SPECIFICATION"
				      "id": "ID2"
				      "message": "hello"
				      "children":
				      - "id": "IDXY"
				      - "id": "IDXZ"
				      - "id": "IDYZ"
				    - "node": "SPECIFICATION"
				      "id": "ID9"
			''')
			commitInRemoteRepository
		]
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo ">>>>>>>>>>>>>>>> got the following test class: org.testeditor.Minimal with id 1.5.1"
				echo "@TESTRUN:ENTER:0.0.0"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:ENTER:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] same local ID, different test case!"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:LEAVE:44e5ddd2:ID9"
				echo "@TESTRUN:LEAVE:0.0.0"
				echo "@TESTRUN:ENTER:0.0.1"
				echo ""
				echo "org.testeditor.Minimal > execute STANDARD_OUT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:ENTER:2e86865c:IDROOT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Running test for org.testeditor.Minimal"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:ENTER:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:ENTER:f960cf39:ID2"
				(>&2 echo "Test message to standard error")
				echo "  some regular message"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:ENTER:c8b68596:ID3"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:ENTER:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:ENTER:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:ENTER:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:ENTER:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:ENTER:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:ENTER:44e5ddd2:ID9"
				echo "    08:24:02 ERROR [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "    08:24:02 WARN  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "    08:24:02 DEBUG [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "    08:24:02 TRACE [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "  gibberish! ERROR WARN INFO DEBUG TRACE This line should only be included in the response for TRACE-level logging"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:LEAVE:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:LEAVE:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:LEAVE:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:LEAVE:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:LEAVE:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:LEAVE:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:LEAVE:c8b68596:ID3"
				echo "   tailing output"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:LEAVE:f960cf39:ID2"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:LEAVE:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Test org.testeditor.Minimal finished with 0 sec. duration."
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:LEAVE:2e86865c:IDROOT"
				echo "@TESTRUN:LEAVE:0.0.1"
			''')
			commitInRemoteRepository
		]

		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		response.status.assertEquals(CREATED.statusCode)
		createTestRequest(testKey).get // wait for completion
		// when
		val result = createNodeRequest(testKey.deriveWithCaseRunId("1").deriveWithCallTreeId('ID9'), 'logLevel=INFO').get.readEntity(String)

		// then
		val properties = new ObjectMapper().readValue(result, Object).assertInstanceOf(List).findFirst [ map |
			"text".equals((map as Map<String, Object>).get("type"))
		].assertInstanceOf(Map)
		properties.get("content").assertInstanceOf(List).assertEquals(
			#['    08:24:02 ERROR [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)',
				'    08:24:02 WARN  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)',
				'    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)'])
	}

	@Test
	def void testThatOnlyLogLinesAreProvided() {
		val testKey = TestExecutionKey.valueOf('0-0')
		val screenshotPath = 'screenshots/test/hello.png'
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFolder('logs')
		remoteGitFolder.newFile('''logs/testrun.«testKey».299900000000.yaml''') => [
			executable = true
			JGitTestUtil.write(it, '''
				"testRuns":
				- "source": "test.tcl"
				  "testRunId": "1"
				  "children" :
				  - "node": "TEST"
				    "id": "ID1"
				    "children":
				    - "node": "SPECIFICATION"
				      "id": "ID2"
				      "children":
				      - "id": "IDXY"
				      - "id": "IDXZ"
				      - "id": "IDYZ"
				    - "node": "SPECIFICATION"
				      "id": "ID9"
				      "message": "hello"
			''')
			commitInRemoteRepository
		]
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				targetDir=".testexecution/artifacts/«testKey.suiteId»/«testKey.suiteRunId»/1"
				mkdir -p ${targetDir}
				printf '"screenshot": "«screenshotPath»"\n' > ${targetDir}/ID9.yaml
				
				echo ">>>>>>>>>>>>>>>> got the following test class: org.testeditor.Minimal with id 1.5.1"
				echo "@TESTRUN:ENTER:0.0.1"
				echo ""
				echo "org.testeditor.Minimal > execute STANDARD_OUT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:ENTER:2e86865c:IDROOT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Running test for org.testeditor.Minimal"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:ENTER:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:ENTER:f960cf39:ID2"
				(>&2 echo "Test message to standard error")
				echo "  some regular message"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:ENTER:c8b68596:ID3"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:ENTER:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:ENTER:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:ENTER:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:ENTER:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:ENTER:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:ENTER:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:LEAVE:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:LEAVE:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:LEAVE:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:LEAVE:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:LEAVE:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:LEAVE:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:LEAVE:c8b68596:ID3"
				echo "   tailing output"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:LEAVE:f960cf39:ID2"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:LEAVE:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Test org.testeditor.Minimal finished with 0 sec. duration."
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:LEAVE:2e86865c:IDROOT"
				echo "@TESTRUN:LEAVE:0.0.1"
			''')
			commitInRemoteRepository
		]

		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		response.status.assertEquals(CREATED.statusCode)
		createTestRequest(testKey).get // wait for completion
		new File(managerWorkspace.root, '.testexecution/artifacts/0/0/1/ID9.yaml').exists.assertTrue(
			'Mocked process did not write yaml file with screenshot information.')

		// when
		val result = createNodeRequest(testKey.deriveWithCaseRunId("1").deriveWithCallTreeId('ID9'), 'logOnly=true').get.readEntity(String)

		// then
		val detailsList = new ObjectMapper().readValue(result, Object).assertInstanceOf(List)
		detailsList.size.assertEquals(1)
		val properties = detailsList.get(0).assertInstanceOf(Map)
		properties.get('type').assertEquals('text')
		properties.get('content').assertEquals(#['    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)'])
	}

	@Test
	def void testThatLogLinesForTestSuiteRunCanBeRetrieved() {
		val testKey = TestExecutionKey.valueOf('0-0')
		val screenshotPath = 'screenshots/test/hello.png'
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFolder('logs')
		remoteGitFolder.newFile('''logs/testrun.«testKey».299900000000.yaml''') => [
			executable = true
			JGitTestUtil.write(it, '''
				"testRuns":
				- "source": "test.tcl"
				  "testRunId": "1"
				  "children" :
				  - "node": "TEST"
				    "id": "ID1"
				    "children":
				    - "node": "SPECIFICATION"
				      "id": "ID2"
				      "children":
				      - "id": "IDXY"
				      - "id": "IDXZ"
				      - "id": "IDYZ"
				    - "node": "SPECIFICATION"
				      "id": "ID9"
				      "message": "hello"
			''')
			commitInRemoteRepository
		]
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				targetDir=".testexecution/artifacts/«testKey.suiteId»/«testKey.suiteRunId»/1"
				mkdir -p ${targetDir}
				printf '"screenshot": "«screenshotPath»"\n' > ${targetDir}/ID9.yaml
				
				echo ">>>>>>>>>>>>>>>> got the following test class: org.testeditor.Minimal with id 1.5.1"
				echo ""
				echo "org.testeditor.Minimal > execute STANDARD_OUT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:ENTER:2e86865c:IDROOT"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Running test for org.testeditor.Minimal"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:ENTER:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:ENTER:f960cf39:ID2"
				(>&2 echo "Test message to standard error")
				echo "  some regular message"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:ENTER:c8b68596:ID3"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:ENTER:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:ENTER:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:ENTER:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:ENTER:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:ENTER:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:ENTER:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                   @STEP:LEAVE:44e5ddd2:ID9"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase                 @COMPONENT:LEAVE:2aa6f5bc:ID8"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase               @MACRO:LEAVE:d295d64c:ID7"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase             @STEP:LEAVE:2f1c1f5f:ID6"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase           @MACRO_LIB:LEAVE:f960cf39:ID5"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase         @MACRO:LEAVE:1cbd1de8:ID4"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase       @STEP:LEAVE:c8b68596:ID3"
				echo "   tailing output"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase     @MACRO_LIB:LEAVE:f960cf39:ID2"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase   @SPECIFICATION_STEP:LEAVE:e9f5018e:ID1"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Test org.testeditor.Minimal finished with 0 sec. duration."
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************"
				echo "    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase @TEST:LEAVE:2e86865c:IDROOT"
				echo ":testTask2Picked up _JAVA_OPTIONS: -Djdk.http.auth.tunneling.disabledSchemes="
			''')
			commitInRemoteRepository
		]

		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		response.status.assertEquals(CREATED.statusCode)
		createTestRequest(testKey).get // wait for completion
		new File(workerWorkspace.root, '.testexecution/artifacts/0/0/1/ID9.yaml').exists.assertTrue(
			'Mocked process did not write yaml file with screenshot information.')

		// when
		val result = createNodeRequest(testKey, 'logLevel=TRACE&logOnly=true').get.readEntity(String)

		// then
		val detailsList = new ObjectMapper().readValue(result, Object).assertInstanceOf(List)
		val properties = detailsList.get(0).assertInstanceOf(Map)
		properties.get('type').assertEquals('text')
		properties.get('content').assertEquals(#[
			'>>>>>>>>>>>>>>>> got the following test class: org.testeditor.Minimal with id 1.5.1',
			'',
			'org.testeditor.Minimal > execute STANDARD_OUT',
			'    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************',
			'    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Running test for org.testeditor.Minimal',
			'    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************',
			'Test message to standard error',
			'  some regular message',
			'    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] HftFixture actionWithStringParam(aString)',
			'   tailing output',
			'    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************',
			'    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase Test org.testeditor.Minimal finished with 0 sec. duration.',
			'    08:24:02 INFO  [Test worker]  [TE-Test: Minimal] AbstractTestCase ****************************************************',
			':testTask2Picked up _JAVA_OPTIONS: -Djdk.http.auth.tunneling.disabledSchemes='
		])
	}

	@Test
	def void testThatRequestIsReturnedEventuallyForLongRunningTests() {
		// given
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "doing something for 5s"
				sleep 5
				echo "doing something for 5s, again"
				sleep 5
				echo "doing something for only 2s)"
				sleep 2 # should timeout twice w/ timeout = 5 sec
				echo "done"
				echo "ok" > test.ok.txt
				exit 0
			''')
			commitInRemoteRepository
		]
		val response = createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		assertThat(response.status).isEqualTo(CREATED.statusCode)

		val longPollingRequest = createAsyncTestRequest(TestExecutionKey.valueOf('0-0')).async
		val statusList = <String>newLinkedList('IDLE')

		// when
		// wait until either the status inidcates it is no longer running, or until near infinity (100) was reached
		for (var i = 0; i < 100 && statusList.head.equals('IDLE') || statusList.head.equals('RUNNING'); i++) {
			val future = longPollingRequest.get
			val pollResponse = future.get(120, TimeUnit.SECONDS)
			assertThat(pollResponse.status).isEqualTo(OK.statusCode)
			statusList.offerFirst(pollResponse.readEntity(String))
			pollResponse.close
			println('still running, sleeping 5 seconds ...')
			Thread.sleep(5000)
		}

		// then
		println('no longer running.')
		statusList => [
			assertThat(head).isEqualTo('SUCCESS')
			tail => [
				val numRunningStatus = takeWhile[it == 'RUNNING'].size
				assertThat(numRunningStatus).isGreaterThanOrEqualTo(2)
				assertThat(drop(numRunningStatus)).allMatch[it == 'IDLE']
			]
		]
	}

	@Test
	def void testThatAllRunningAndTerminatedTestsAreReturned() {
		// given
		new File(managerWorkspace.root, '''calledCount.txt''').delete
		remoteGitFolder.newFile('''gradlew''') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "called" >> calledCount.txt
				called=`cat calledCount.txt | wc -l`
				echo "called $called times"
				if [ "$called" = "3" ]; then
				  echo "lastcall" > finished.txt
				  sleep 20; exit 0
				elif [ "$called" = "2" ]; then
				  echo "secondcall" > finished.txt
				  exit 0
				elif [ "$called" = "1" ]; then
				  echo "firstcall" > finished.txt
				  exit 1
				fi
			''')
			commitInRemoteRepository
		]
		val expectedap = #['FAILED', 'SUCCESS', 'RUNNING']
		expectedap.map [ name |
			remoteGitFolder.newFile('''Test«name».tcl''').commitInRemoteRepository
			return '''Test«name».tcl'''
		].forEach [ name, index |
			new File(managerWorkspace.root, '''finished.txt''').delete
			val response = createLaunchNewRequest().post(Entity.entity(#[name], MediaType.APPLICATION_JSON_TYPE))
			assertThat(response.status).isEqualTo(CREATED.statusCode)
			System.out.println('Job added here: ' + response.stringHeaders.get('Location'))

			if (createTestRequest(TestExecutionKey.valueOf('''0-«index»''')).get.readEntity(String) == 'RUNNING') {
				Thread.yield
			}
		]

		// when
		val response = createRequest('''test-suite/status''').get
		response.bufferEntity

		// then
		val json = response.readEntity(String)
		new SoftAssertions => [
			expectedap.forEach [ status, index |
				assertThat(json).matches(Pattern.compile(
				'''.*"suiteRunId"\s*:\s*"«index»"[^}]*}\s*,\s*"status"\s*:\s*"«status»".*''', Pattern.DOTALL))
			]
			assertAll
		]
		val actuals = response.readEntity(new GenericType<Iterable<Object>>() {
		})
		assertThat(actuals).size.isEqualTo(3)
		
		// cleanup -- kill the 
		createCallTreeRequest(TestExecutionKey.valueOf('0-2')).delete
		Thread.sleep(2000)
	}

	@Test
	def void testThatDeletingNonExistingTestRunRespondsWith404() {
		// given
		val nonExistingTestRun = TestExecutionKey.valueOf('47-11')
		val request = createCallTreeRequest(nonExistingTestRun)

		// when
		val response = request.delete

		// then
		assertThat(response.status).isEqualTo(NOT_FOUND.statusCode)
	}

	@Test
	def void testThatDeletingPreviouslyStartedTestRespondsWith200() {
		// given
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "I will run forever!"
				while true; do sleep 1; done
			''')
			commitInRemoteRepository
		]
		val launchResponse = createLaunchNewRequest().buildPost(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE)).submit.get

		val testRunIdMatcher = Pattern.compile("\\[http://localhost:[0-9]+/test-suite/(\\d+)/(\\d+)\\]").matcher(
			launchResponse.headers.get("Location").toString)
		testRunIdMatcher.find.assertTrue
		val testRun = TestExecutionKey.valueOf('''«testRunIdMatcher.group(1)»-«testRunIdMatcher.group(2)»''')

		// when
		val response = createCallTreeRequest(testRun).delete

		// then
		assertThat(response.status).isEqualTo(OK.statusCode)
		createTestRequest(testRun).get
	}

	@Test
	def void testThatTestRunIsFailedAfterBeingDeleted() {
		// given
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "I will run forever!"
				while true; do sleep 1; done
			''')
			commitInRemoteRepository
		]
		val launchResponse = createLaunchNewRequest().buildPost(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE)).submit.get
		val testRunIdMatcher = Pattern.compile("\\[http://localhost:[0-9]+/test-suite/(\\d+)/(\\d+)\\]").matcher(
			launchResponse.headers.get("Location").toString)
		testRunIdMatcher.find.assertTrue
		val testRun = TestExecutionKey.valueOf('''«testRunIdMatcher.group(1)»-«testRunIdMatcher.group(2)»''')
		val statusRequest = createTestRequest(testRun)
		while(statusRequest.get(String) == 'IDLE') {
			println('waiting for worker to accept the test job...')
			Thread.sleep(100)
		}

		// when
		createCallTreeRequest(testRun).delete

		// then
		val actualTestStatus = statusRequest.get
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('FAILED')
	}
	
	@Test
	def void testThatLatestWorkspaceIsPulledFromRepositoryBeforeTestExecution() {
		// given
		val testFile = 'test.tcl'
		remoteGitFolder.newFile(testFile).commitInRemoteRepository
		val gradlew = remoteGitFolder.newFile('gradlew') => [
			executable = true
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "Hello World"
			''')
			commitInRemoteRepository
		]
		createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		createTestRequest(TestExecutionKey.valueOf('0-0')).get

		// when
		gradlew => [
			JGitTestUtil.write(it, '''
				#!/bin/sh
				echo "Hello Update" | tee updated.state
			''')
			commitInRemoteRepository
		]
		createLaunchNewRequest().post(Entity.entity(#[testFile], MediaType.APPLICATION_JSON_TYPE))
		val actualTestStatus = createTestRequest(TestExecutionKey.valueOf('0-1')).get

		// then
		assertThat(actualTestStatus.readEntity(String)).isEqualTo('SUCCESS')
		val executionResult = workerWorkspace.root.toPath.resolve('updated.state').toFile
		assertThat(executionResult).exists
	}

}
