package org.testeditor.web.backend.testexecution.distributed.common

import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus

interface WorkerManagerAPI<R,S> {

	def R registerWorker(Worker worker)

	def R unregisterWorker(String id)
	
	def R upload(String workerId, TestExecutionKey jobId, String fileName, S content)
	
	def R updateStatus(String workerId, TestExecutionKey jobId, TestStatus status)

}
