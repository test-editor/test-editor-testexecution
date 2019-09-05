package org.testeditor.web.backend.testexecution.manager

import java.io.InputStream
import javax.ws.rs.core.Response
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestStatus

interface WorkersAPI {

	def Response registerWorker(WorkerClient worker)

	def Response unregisterWorker(String id)
	
	def Response upload(String workerId, TestExecutionKey jobId, String fileName, InputStream content)
	
	def Response updateStatus(String workerId, TestExecutionKey jobId, TestStatus status)

}
