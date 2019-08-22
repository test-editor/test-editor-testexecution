package org.testeditor.web.backend.testexecution.worker

import java.io.File
import java.net.URI
import java.net.URLEncoder
import java.nio.file.Files
import java.time.Instant
import java.util.Map
import java.util.Set
import javax.inject.Inject
import javax.inject.Singleton
import javax.ws.rs.DELETE
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.core.Response
import javax.ws.rs.core.Response.Status
import javax.ws.rs.core.UriBuilder
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestExecutorProvider
import org.testeditor.web.backend.testexecution.TestLogWriter
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.TestStatusMapper
import org.testeditor.web.backend.testexecution.TestSuiteResource
import org.testeditor.web.backend.testexecution.manager.TestJob

import static java.nio.charset.StandardCharsets.UTF_8
import static java.nio.file.StandardOpenOption.APPEND
import static java.nio.file.StandardOpenOption.CREATE
import static java.nio.file.StandardOpenOption.TRUNCATE_EXISTING
import static org.testeditor.web.backend.testexecution.worker.WorkerState.*

@Path('/worker')
@Singleton
class WorkerResource implements WorkerAPI, WorkerStateContext {

	val Map<WorkerState, WorkerAPI> states
	var WorkerAPI state

	@Inject
	new(TestExecutorProvider executorProvider, TestStatusMapper statusMapper, TestLogWriter logWriter) {
		states = #{
			IDLE -> new IdleWorker(this, logWriter, executorProvider, statusMapper),
			BUSY -> new BusyWorker(this)
		}
		state = states.get(IDLE)
	}

	override setState(WorkerState state) {
		this.state = states.get(state)
	}

	static val logger = LoggerFactory.getLogger(WorkerResource)

	override Logger getLogger() { return logger }

	@GET
	def Worker getWorkerState() {
	}

	@GET
	@Path('capabilities')
	def Set<String> getWorkerCapabilities() {
	}

	@GET
	@Path('job')
	def TestJob getTestJobState() {
	}

	@POST
	@Path('job')
	override executeTestJob(TestJob job) {
		return state.executeTestJob(job)
	}

	@DELETE
	@Path('job')
	def Worker cancelTestJob() {
	}

}

enum WorkerState {

	IDLE,
	BUSY

}

interface WorkerStateContext {

	def void setState(WorkerState state)

	def Logger getLogger()

}

@FinalFieldsConstructor
class IdleWorker implements WorkerAPI {

	val extension WorkerStateContext
	val extension TestLogWriter logWriter
	val TestExecutorProvider executorProvider
	val TestStatusMapper statusMapper

	override Response executeTestJob(TestJob job) {
		val suiteKey = new TestExecutionKey("0") // default suite
		val executionKey = statusMapper.deriveFreshRunId(suiteKey)
		val builder = executorProvider.testExecutionBuilder(executionKey, job.resourcePaths, '') // commit id unknown
		val logFile = builder.environment.get(TestExecutorProvider.LOGFILE_ENV_KEY)
		val callTreeFileName = builder.environment.get(TestExecutorProvider.CALL_TREE_YAML_FILE)
		logger.
			info('''Starting test for resourcePaths='«job.resourcePaths.join(',')»' logging into logFile='«logFile»', callTreeFile='«callTreeFileName»'.''')
		val callTreeFile = new File(callTreeFileName)
		callTreeFile.writeCallTreeYamlPrefix(executorProvider.yamlFileHeader(executionKey, Instant.now, job.resourcePaths))
		val testProcess = builder.start
		statusMapper.addTestSuiteRun(executionKey, testProcess)[status|callTreeFile.writeCallTreeYamlSuffix(status)]
		testProcess.logToStandardOutAndIntoFile(new File(logFile))
		val uri = new URI(UriBuilder.fromResource(TestSuiteResource).build.toString +
			'''/«URLEncoder.encode(executionKey.suiteId, "UTF-8")»/«URLEncoder.encode(executionKey.suiteRunId,"UTF-8")»''')
		return Response.created(uri).build
	}

	private def File writeCallTreeYamlPrefix(File callTreeYamlFile, String fileHeader) {
		callTreeYamlFile.parentFile.mkdirs
		Files.write(callTreeYamlFile.toPath, fileHeader.getBytes(UTF_8), CREATE, TRUNCATE_EXISTING)
		return callTreeYamlFile
	}

	private def void writeCallTreeYamlSuffix(File callTreeYamlFile, TestStatus testStatus) {
		Files.write(callTreeYamlFile.toPath, #['''"status": "«testStatus»"'''], UTF_8, APPEND)
	}

}

@FinalFieldsConstructor
class BusyWorker implements WorkerAPI {

	extension val WorkerStateContext context

	override executeTestJob(TestJob job) {
		return Response.status(Status.CONFLICT).entity('worker is busy').build
	}

}
