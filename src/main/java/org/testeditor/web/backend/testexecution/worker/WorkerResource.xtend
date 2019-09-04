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
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriBuilder
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestExecutorProvider
import org.testeditor.web.backend.testexecution.TestLogWriter
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.TestSuiteResource
import org.testeditor.web.backend.testexecution.manager.TestJob

import static java.nio.charset.StandardCharsets.UTF_8
import static java.nio.file.StandardOpenOption.APPEND
import static java.nio.file.StandardOpenOption.CREATE
import static java.nio.file.StandardOpenOption.TRUNCATE_EXISTING
import static javax.ws.rs.core.Response.Status.CONFLICT
import static javax.ws.rs.core.Response.Status.NOT_FOUND
import static org.testeditor.web.backend.testexecution.worker.WorkerState.*
import javax.ws.rs.core.MediaType

@Path('/worker')
@Singleton
class WorkerResource implements WorkerAPI, WorkerStateContext {

	val Map<WorkerState, WorkerAPI> states
	var WorkerAPI state

	@Inject
	new(TestExecutionWorkerConfiguration config, TestExecutorProvider executorProvider, WorkerStatusManager statusManager, TestLogWriter logWriter) {
		states = #{
			IDLE -> new IdleWorker(this, logWriter, executorProvider, statusManager),
			BUSY -> new BusyWorker(this, statusManager)
		}
		state = states.get(IDLE)
	}

	override setState(WorkerState state) {
		this.state = states.get(state)
	}

	static val logger = LoggerFactory.getLogger(WorkerResource)

	override Logger getLogger() { return logger }

	@GET
	@Path('job')
	@Produces(MediaType.TEXT_PLAIN)
	override synchronized Response getTestJobState(@QueryParam('wait') Boolean wait) {
		return state.getTestJobState(wait ?: false)
	}

	@POST
	@Path('job')
	override synchronized executeTestJob(TestJob job) {
		return state.executeTestJob(job)
	}

	@DELETE
	@Path('job')
	override synchronized Response cancelTestJob() {
		return state.cancelTestJob
	}

	override transitionTo(WorkerState state, ()=>Void action) {
		this.state = state
		action.apply
	}

}

enum WorkerState {

	IDLE,
	BUSY

}

interface WorkerStateContext {

	def void setState(WorkerState state)

	def void transitionTo(WorkerState state, ()=>Void action)

	def Logger getLogger()

}

@FinalFieldsConstructor
class IdleWorker implements WorkerAPI {

	val extension WorkerStateContext
	val extension TestLogWriter logWriter
	val TestExecutorProvider executorProvider
	val WorkerStatusManager statusManager

	override Response executeTestJob(TestJob job) {
		try {
			val suiteKey = new TestExecutionKey("0") // default suite
			val executionKey = statusManager.deriveFreshRunId(suiteKey)
			val builder = executorProvider.testExecutionBuilder(executionKey, job.resourcePaths, '') // commit id unknown
			val logFile = builder.environment.get(TestExecutorProvider.LOGFILE_ENV_KEY)
			val callTreeFileName = builder.environment.get(TestExecutorProvider.CALL_TREE_YAML_FILE)
			logger.
				info('''Starting test for resourcePaths='«job.resourcePaths.join(',')»' logging into logFile='«logFile»', callTreeFile='«callTreeFileName»'.''')
			val callTreeFile = new File(callTreeFileName)
			callTreeFile.writeCallTreeYamlPrefix(executorProvider.yamlFileHeader(executionKey, Instant.now, job.resourcePaths))
			val testProcess = builder.start
			statusManager.addTestSuiteRun(testProcess) [ status |
				callTreeFile.writeCallTreeYamlSuffix(status)
			// TODO send PUT request to test execution manager to inform him of the completed test execution
			]
			testProcess.logToStandardOutAndIntoFile(new File(logFile))
			val uri = new URI(UriBuilder.fromResource(TestSuiteResource).build.toString +
				'''/«URLEncoder.encode(executionKey.suiteId, "UTF-8")»/«URLEncoder.encode(executionKey.suiteRunId,"UTF-8")»''')

			state = BUSY

			return Response.created(uri).build
		} catch (Exception ex) {
			logger.error(ex.message)
			ex.printStackTrace
			return Response.serverError.entity(ex.message).build
		}

	}

	override cancelTestJob() {
		return Response.status(NOT_FOUND).entity('worker is idle').build
	}

	override getTestJobState(Boolean wait) {
		return Response.ok(TestStatus.IDLE.name).build
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
	val WorkerStatusManager statusManager

	override executeTestJob(TestJob job) {
		return Response.status(CONFLICT).entity('worker is busy').build
	}

	override cancelTestJob() {
		statusManager.terminateTestSuiteRun
		state = IDLE
		return Response.ok.build
	}

	override getTestJobState(Boolean wait) {
		val status = if (wait) {
				statusManager.waitForStatus
			} else {
				statusManager.getStatus
			}

		if (status !== TestStatus.RUNNING) {
			state = IDLE
		}

		return Response.ok(status.name).build
	}

}
