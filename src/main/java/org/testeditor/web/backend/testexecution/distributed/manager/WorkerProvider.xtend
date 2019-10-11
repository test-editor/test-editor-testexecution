package org.testeditor.web.backend.testexecution.distributed.manager

import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo

interface WorkerProvider {

	def Iterable<WorkerInfo> getWorkers()

	def void assign(WorkerInfo worker, TestJob job)

	def void cancel(WorkerInfo worker)
}
