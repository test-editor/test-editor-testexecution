package org.testeditor.web.backend.testexecution.distributed.manager

import java.util.concurrent.CompletionStage
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.StatusAwareTestJobStore
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo

interface WorkerProvider extends StatusAwareTestJobStore {

	def Iterable<WorkerInfo> getWorkers()
	
	def Iterable<WorkerInfo> idleWorkers()
	
	def WorkerInfo workerForJob(TestJobInfo job)

	def CompletionStage<TestStatus> assign(WorkerInfo worker, TestJob job)

	def void cancel(WorkerInfo worker)
}
