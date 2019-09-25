package org.testeditor.web.backend.testexecution.worker

import java.io.File
import java.net.URI
import java.net.URLEncoder
import java.nio.file.Files
import java.time.Instant
import java.util.Map
import java.util.concurrent.ExecutorCompletionService
import java.util.concurrent.ForkJoinPool
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton
import javax.ws.rs.DELETE
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.MediaType
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
import static org.testeditor.web.backend.testexecution.worker.WorkerStateEnum.*
import java.util.concurrent.TimeUnit

@Path('/worker')
@Singleton
class WorkerResource implements WorkerAPI, WorkerStateContext {

	val Map<WorkerStateEnum, WorkerState> states
	var WorkerState state
	val TestExecutionManagerClient executionManager

	@Inject
	new(TestExecutionManagerClient executionManager, TestExecutorProvider executorProvider, WorkerStatusManager statusManager,
		TestLogWriter logWriter, TestResultWatcher watcher, @Named('httpClientExecutor') ForkJoinPool jobExecutor) {
		this.executionManager = executionManager
		states = #{
			IDLE -> new IdleWorker(executionManager, this, logWriter, executorProvider, statusManager, watcher, jobExecutor),
			BUSY -> new BusyWorker(executionManager, this, statusManager)
		}
		setState(IDLE)
	}

	override setState(WorkerStateEnum state) {
		this.state = states.get(state)
		this.state.onEntry
	}

	static val logger = LoggerFactory.getLogger(WorkerResource)

	override Logger getLogger() { return logger }

	@GET
	@Path('registered')
	override isRegistered() {
		return state.isRegistered
	}

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

	override transitionTo(WorkerStateEnum state, ()=>Void action) {
		setState(state)
		action.apply
	}
}

enum WorkerStateEnum {

	IDLE,
	BUSY

}

interface WorkerState extends WorkerAPI {

	def void onEntry()

}

interface WorkerStateContext {

	def void setState(WorkerStateEnum state)

	def void transitionTo(WorkerStateEnum state, ()=>Void action)

	def Logger getLogger()

}

@FinalFieldsConstructor
abstract class BaseWorkerState implements WorkerState {
	protected val TestExecutionManagerClient executionManager
	
	override isRegistered() {
		return Response.ok(executionManager.registered).build
	}
	
}

@FinalFieldsConstructor
class IdleWorker extends BaseWorkerState {

	val extension WorkerStateContext 
	val extension TestLogWriter logWriter
	val TestExecutorProvider executorProvider
	val WorkerStatusManager statusManager
	val TestResultWatcher testResultWatcher
	val ForkJoinPool jobExecutor

	override onEntry() {
		logger.info('''worker has entered idle state''')
	}

	override Response executeTestJob(TestJob job) {
		try {
			val builder = executorProvider.testExecutionBuilder(job.id, job.resourcePaths, '') // commit id unknown
			val logFile = builder.environment.get(TestExecutorProvider.LOGFILE_ENV_KEY)
			val callTreeFileName = builder.environment.get(TestExecutorProvider.CALL_TREE_YAML_FILE)
			logger.
				info('''Starting test for resourcePaths='«job.resourcePaths.join(',')»' logging into logFile='«logFile»', callTreeFile='«callTreeFileName»'.''')
			val callTreeFile = new File(callTreeFileName)
			callTreeFile.writeCallTreeYamlPrefix(executorProvider.yamlFileHeader(job.id, Instant.now, job.resourcePaths))

			testResultWatcher.watch(job.id)
			val testProcess = builder.start
			statusManager.addTestSuiteRun(testProcess) [ status |
				logger.info('''process executing job "«job.id»" has completed with status "«status»""''')
				callTreeFile.writeCallTreeYamlSuffix(status)
				testResultWatcher.waitForWatchPhase
				testResultWatcher.stopWatching
				logger.info('waiting for background tasks uploading test artifacts to finish')
				if (!jobExecutor.awaitQuiescence(2, TimeUnit.SECONDS)) {
					logger.warn('timed out while waiting for upload tasks to finish')
				}
				executionManager.updateStatus(job.id, statusManager.getStatus)
			]
			testProcess.logToStandardOutAndIntoFile(new File(logFile))
			val uri = new URI(UriBuilder.fromResource(TestSuiteResource).build.toString +
				'''/«URLEncoder.encode(job.id.suiteId, "UTF-8")»/«URLEncoder.encode(job.id.suiteRunId,"UTF-8")»''')

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
		return Response.ok(statusManager.getStatus.name).build
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
class BusyWorker extends BaseWorkerState {

	extension val WorkerStateContext context
	val WorkerStatusManager statusManager

	override onEntry() {
		logger.info('''worker has entered busy state''')
	}

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
