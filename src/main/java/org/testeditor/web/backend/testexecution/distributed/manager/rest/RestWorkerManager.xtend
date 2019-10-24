package org.testeditor.web.backend.testexecution.distributed.manager.rest

import javax.inject.Singleton
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo
import org.testeditor.web.backend.testexecution.distributed.manager.WorkerProvider
import java.util.Optional
import org.testeditor.web.backend.testexecution.common.TestStatus

@Singleton
class RestWorkerManager implements WorkerProvider {
	
	val workers = <Worker, TestJobInfo>newHashMap
	
	override getWorkers() {
		return newHashSet => [ addAll(workers.keySet)]
	}
	
	override idleWorkers() {
		return workers.filter[worker, job|job == TestJob.NONE].keySet.filter(WorkerInfo)
	}
	
	override workerForJob(TestJobInfo job) {
		return workers.keySet.findFirst[workers.get(it) == job]
	}
	
	override assign(WorkerInfo workerInfo, TestJob job) {
		return if (workers.get(workerInfo) === TestJob.NONE) {
			val worker = workerInfo as Worker
			worker.startJob(job) => [
				thenRunAsync[workers.replace(worker, TestJob.NONE)]
			]
		} else {
			//TODO throw exception
		}
	}
	
	override cancel(WorkerInfo workerInfo) {
		if (workers.containsKey(workerInfo)) {
			(workerInfo as Worker).cancel
		} else {
			//TODO throw exception
		}
	}
	
	override testJobExists(TestExecutionKey key) {
		return workers.values.exists[id == key]
	}
	
	override getJsonCallTree(TestExecutionKey key) {
		return key.worker.flatMap[getJsonCallTree(key)]
	}
	
	override getStatusAll() {
		return workers.filter[__, job| job !== TestJob.NONE].keySet.toMap([workers.get(it).id],[checkStatus])
	}
	
	override getStatus(TestExecutionKey key) {
		return key.worker.map[checkStatus].orElse(TestStatus.IDLE)
	}
	
	override waitForStatus(TestExecutionKey key) {
		return key.worker.map[waitForStatus].orElse(TestStatus.IDLE)
	}
	
	private def getWorker(TestExecutionKey key) {
		return Optional.ofNullable(workers.filter[__, job| job.id == key].keySet.head)
	}
	
}