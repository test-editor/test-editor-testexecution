package org.testeditor.web.backend.testexecution.distributed.worker.rest

import java.io.File
import java.nio.file.Files
import java.util.Map
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton
import javax.ws.rs.DELETE
import javax.ws.rs.GET
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.Produces
import javax.ws.rs.QueryParam
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.common.WorkerAPI

import static javax.ws.rs.core.Response.Status.CONFLICT
import static javax.ws.rs.core.Response.Status.NOT_FOUND
import static org.testeditor.web.backend.testexecution.distributed.worker.rest.WorkerStateEnum.*

@Path('/worker')
@Singleton
class WorkerResource implements WorkerAPI<Response>, WorkerStateContext {

	static val logger = LoggerFactory.getLogger(WorkerResource)

	@Inject @Named('workspace') File workspace

	val Map<WorkerStateEnum, WorkerState> states
	var WorkerState state

	@Inject
	new(Worker delegateWorker) {
		states = #{
			IDLE -> new IdleWorker(this, delegateWorker),
			BUSY -> new BusyWorker(this, delegateWorker)
		}
		setState(IDLE)
	}

	override setState(WorkerStateEnum state) {
		this.state = states.get(state)
		this.state.onEntry
	}

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

	@GET
	@Path("logs/{suiteId}/{suiteRunId}")
	@Produces(MediaType.TEXT_PLAIN)
	def synchronized Response getLog(@PathParam("suiteId") String suiteId, @PathParam("suiteRunId") String suiteRunId) {

		val key = new TestExecutionKey(suiteId, suiteRunId)
		logger.info('''sending log file for job id "«key»"''')
		return Response.ok(Files.newInputStream(key.getLogFile(workspace))).build
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

interface WorkerState extends WorkerAPI<Response> {

	def void onEntry()

}

interface WorkerStateContext {

	def void setState(WorkerStateEnum state)

	def void transitionTo(WorkerStateEnum state, ()=>Void action)

	def Logger getLogger()

}

abstract class BaseWorkerState implements WorkerState {

	override isRegistered() {
		return Response.ok(true).build
	}

}

@FinalFieldsConstructor
class IdleWorker extends BaseWorkerState {

	val extension WorkerStateContext
	val Worker delegate

	override onEntry() {
		logger.info('''worker has entered idle state''')
	}

	override Response executeTestJob(TestJob job) {
		state = BUSY
		delegate.startJob(job)
		return Response.ok.build
	}

	override cancelTestJob() {
		return Response.status(NOT_FOUND).entity('worker is idle').build
	}

	override getTestJobState(Boolean wait) {
		return Response.ok(delegate.checkStatus.name).build
	}

}

@FinalFieldsConstructor
class BusyWorker extends BaseWorkerState {

	extension val WorkerStateContext context
	val Worker delegate

	override onEntry() {
		logger.info('''worker has entered busy state''')
	}

	override executeTestJob(TestJob job) {
		return Response.status(CONFLICT).entity('worker is busy').build
	}

	override cancelTestJob() {
		delegate.kill
		state = IDLE
		return Response.ok.build
	}

	override getTestJobState(Boolean wait) {
		val status = if (wait) {
				delegate.waitForStatus
			} else {
				delegate.checkStatus
			}

		if (status !== TestStatus.RUNNING) {
			state = IDLE
		}

		return Response.ok(status.name).build
	}

}
