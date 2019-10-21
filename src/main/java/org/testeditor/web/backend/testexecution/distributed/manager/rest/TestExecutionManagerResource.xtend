package org.testeditor.web.backend.testexecution.distributed.manager.rest

import java.io.InputStream
import javax.inject.Inject
import javax.ws.rs.core.Response
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.TestExecutionManager
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.common.WorkerManagerAPI
import org.testeditor.web.backend.testexecution.distributed.manager.WorkerProvider

class TestExecutionManagerResource implements WorkerManagerAPI<Response, InputStream>{
	@Inject TestExecutionManager manager
	@Inject extension WorkerProvider workerProvider
	
	override registerWorker(Worker worker) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override unregisterWorker(String id) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override upload(String workerId, TestExecutionKey jobId, String fileName, InputStream content) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override updateStatus(String workerId, TestExecutionKey jobId, TestStatus status) {
		workers.filter(RestWorkerClient).findFirst[uri == workerId]?.updateStatus(jobId, status)
		return Response.ok.build
	}
	
}