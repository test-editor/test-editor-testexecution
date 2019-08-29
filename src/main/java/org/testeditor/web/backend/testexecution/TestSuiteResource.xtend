package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import java.io.File
import java.io.FileNotFoundException
import java.net.URI
import java.net.URLEncoder
import java.nio.file.Files
import java.util.List
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.ws.rs.Consumes
import javax.ws.rs.DELETE
import javax.ws.rs.DefaultValue
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.container.AsyncResponse
import javax.ws.rs.container.Suspended
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.Response.Status
import javax.ws.rs.core.UriBuilder
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.loglines.LogFinder
import org.testeditor.web.backend.testexecution.loglines.LogLevel
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager
import org.testeditor.web.backend.testexecution.manager.TestJob
import org.testeditor.web.backend.testexecution.screenshots.ScreenshotFinder

import static java.nio.charset.StandardCharsets.UTF_8
import static java.nio.file.StandardOpenOption.*

import static extension com.fasterxml.jackson.core.util.BufferRecyclers.quoteAsJsonText

@Path("/test-suite")
@Consumes(MediaType.APPLICATION_JSON, MediaType.TEXT_PLAIN)
class TestSuiteResource {

	public static val LONG_POLLING_TIMEOUT_SECONDS = 5
	static val logger = LoggerFactory.getLogger(TestSuiteResource)

	@Inject TestExecutorProvider executorProvider
	@Inject TestStatusMapper statusMapper
	@Inject extension TestLogWriter logWriter
	@Inject Executor executor
	@Inject TestExecutionCallTree testExecutionCallTree
	@Inject ScreenshotFinder screenshotFinder
	@Inject LogFinder logFinder
	@Inject TestExecutionManager manager

	@GET
	@Path("{suiteId}/{suiteRunId}/{caseRunId : ([^?/]+)?}/{callTreeId : ([^?/]+)?}")
	@Produces(MediaType.APPLICATION_JSON)
	def Response testSuiteCalltreeNode(
		@PathParam("suiteId") String suiteId,
		@PathParam("suiteRunId") String suiteRunId,
		@PathParam("caseRunId") String caseRunId,
		@PathParam("callTreeId") String callTreeId,
		@QueryParam("logOnly") boolean logOnly,
		@QueryParam("logLevel") @DefaultValue('TRACE') LogLevel logLevel
	) {
		var response = Response.status(Status.NOT_FOUND).build
		var executionKey = new TestExecutionKey(suiteId, suiteRunId)
		val latestCallTree = executorProvider.getTestFiles(executionKey).filter[name.endsWith('.yaml')].sortBy[name].last
		if (latestCallTree !== null) {
			if (!caseRunId.nullOrEmpty) {
				executionKey = executionKey.deriveWithCaseRunId(caseRunId)
				if (!callTreeId.nullOrEmpty) {
					executionKey = executionKey.deriveWithCallTreeId(callTreeId)
				}
			}
			var logLines = newLinkedList
			var warning = ''
			try {
				logLines.addAll(
					logFinder.getLogLinesForTestStep(executionKey, logLevel).map[new String(quoteAsJsonText)]
				)
			} catch (FileNotFoundException e) {
				warning = '''No log file for test execution key '«executionKey.toString»'.'''
				logger.warn(warning, e)
			}

			val resultList = newLinkedList('''{ "type": "text", "content": ["«logLines.join('", "')»"]}''')

			if (!logOnly) {
				testExecutionCallTree.readFile(executionKey, latestCallTree)
				val callTreeResultString = testExecutionCallTree.getNodeJson(executionKey)
				resultList += '''{ "type": "properties", "content": «callTreeResultString» }'''
				resultList += screenshotFinder.getScreenshotPathsForTestStep(executionKey).map [
					'''{ "type": "image", "content": "«it»" }'''
				]
			}
			val jsonResultString = '[' + resultList.join(',') + ']'

			val responseBuilder = Response.ok(jsonResultString)
			response = if (warning.nullOrEmpty) {
				responseBuilder.build
			} else {
				responseBuilder.header('Warning', '''299 «warning»''').build
			}
		}

		return response
	}

	@GET
	@Path("{suiteId}/{suiteRunId}")
	@Produces(MediaType.APPLICATION_JSON)
	def void testSuiteRunStatus(
		@PathParam("suiteId") String suiteId,
		@PathParam("suiteRunId") String suiteRunId,
		@QueryParam("status") String status,
		@QueryParam("wait") String wait,
		@Suspended AsyncResponse response
	) {
		if (status !== null) {			
			val executionKey = new TestExecutionKey(suiteId, suiteRunId)
			if (wait !== null) {
				executor.execute [
					waitForStatus(executionKey, response)
				]
			} else {
				val suiteStatus = statusMapper.getStatus(executionKey)
				response.resume(Response.ok(suiteStatus.name).build)
			}
		} else {
			// get the latest call tree of the given resource
			val latestCallTree = executorProvider.getTestFiles(new TestExecutionKey(suiteId, suiteRunId)).filter[name.endsWith('.yaml')].sortBy[name].
				reverse.head
			if (latestCallTree !== null) {
				val mapper = new ObjectMapper(new YAMLFactory)
				val jsonTree = mapper.readTree(latestCallTree)
				response.resume(
					Response.ok(jsonTree.toString).build
				)
			} else {
				response.resume(
					Response.status(Status.NOT_FOUND).build
				)
			}
		}
	}
	
	
	@DELETE
	@Path("{suiteId}/{suiteRunId}")
	@Produces(MediaType.APPLICATION_JSON)
	def Response terminateTestSuiteRun(
		@PathParam("suiteId") String suiteId,
		@PathParam("suiteRunId") String suiteRunId
	) {
		val executionKey = new TestExecutionKey(suiteId, suiteRunId)
		return if (statusMapper.getStatus(executionKey) === TestStatus.RUNNING) {
			statusMapper.terminateTestSuiteRun(executionKey)
			Response.ok.build
		} else {
			Response.status(Status.NOT_FOUND).build	
		}
	}

	@POST
	@Path("launch-new")
	def Response launchNewSuiteWith(List<String> resourcePaths) {
		val suiteKey = new TestExecutionKey("0") // default suite
		val executionKey = statusMapper.deriveFreshRunId(suiteKey)
		manager.addJob(new TestJob(executionKey, emptySet, resourcePaths))
		val uri = new URI(UriBuilder.fromResource(TestSuiteResource).build.toString +
			'''/«URLEncoder.encode(executionKey.suiteId, "UTF-8")»/«URLEncoder.encode(executionKey.suiteRunId,"UTF-8")»''')
		return Response.created(uri).build
	}

	@GET
	@Path("status")
	@Produces(MediaType.APPLICATION_JSON)
	def Iterable<TestSuiteStatusInfo> getStatusAll() {
		return statusMapper.allTestSuites
	}

	private def File writeCallTreeYamlPrefix(File callTreeYamlFile, String fileHeader) {
		callTreeYamlFile.parentFile.mkdirs
		Files.write(callTreeYamlFile.toPath, fileHeader.getBytes(UTF_8), CREATE, TRUNCATE_EXISTING)
		return callTreeYamlFile
	}

	private def void writeCallTreeYamlSuffix(File callTreeYamlFile, TestStatus testStatus) {
		Files.write(callTreeYamlFile.toPath, #['''"status": "«testStatus»"'''], UTF_8, APPEND)
	}

	private def void waitForStatus(TestExecutionKey executionKey, AsyncResponse response) {
		response.setTimeout(LONG_POLLING_TIMEOUT_SECONDS, TimeUnit.SECONDS)
		response.timeoutHandler = [
			resume(Response.ok(TestStatus.RUNNING.name).build)
		]

		try {
			val status = statusMapper.waitForStatus(executionKey)
			response.resume(Response.ok(status.name).build)
		} catch (InterruptedException ex) {
		} // timeout handler takes care of response
	}

}
