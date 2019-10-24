package org.testeditor.web.backend.testexecution.distributed.manager

import java.util.concurrent.CompletionStage
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.StatusAwareTestJobStore
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo

interface WorkerProvider extends StatusAwareTestJobStore {
	
	def Iterable<String> getWorkers()
	
	def Iterable<String> idleWorkers()
	
	def String workerForJob(TestJobInfo job)

	def CompletionStage<TestStatus> assign(String workerId, TestJobInfo job)

	def void cancel(String workerId)
}

interface WritableWorkerProvider<T extends WorkerInfo> extends WorkerProvider {
	def void addWorker(T worker)
}
