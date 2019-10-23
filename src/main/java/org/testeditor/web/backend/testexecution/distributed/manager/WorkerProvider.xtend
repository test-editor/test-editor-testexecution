package org.testeditor.web.backend.testexecution.distributed.manager

import java.util.concurrent.CompletionStage
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.StatusAwareTestJobStore
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo

interface WorkerProvider<T extends WorkerInfo> extends StatusAwareTestJobStore {
	
	def Iterable<T> getWorkers()
	
	def Iterable<T> idleWorkers()
	
	def T workerForJob(TestJobInfo job)

	def CompletionStage<TestStatus> assign(T worker, TestJob job)

	def void cancel(T worker)
}

interface WritableWorkerProvider<T extends WorkerInfo> extends WorkerProvider<T> {
	def void addWorker(T worker)
}
