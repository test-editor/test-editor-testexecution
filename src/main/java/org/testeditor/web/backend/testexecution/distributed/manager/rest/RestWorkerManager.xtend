package org.testeditor.web.backend.testexecution.distributed.manager.rest

import java.util.Optional
import javax.inject.Singleton
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.manager.NoSuchWorkerException
import org.testeditor.web.backend.testexecution.distributed.manager.WritableWorkerProvider

@Singleton
class RestWorkerManager implements WritableWorkerProvider<RestWorkerClient> {
	
	val workers = <RestWorkerClient, TestJobInfo>newHashMap
	
	override getWorkers() {
		return newHashSet => [ addAll(workers.keySet)]
	}
	
	override idleWorkers() {
		return workers.filter[worker, job|job == TestJob.NONE].keySet
	}
	
	override workerForJob(TestJobInfo job) {
		return workers.keySet.findFirst[workers.get(it) == job]
	}
	
	override assign(RestWorkerClient worker, TestJob job) {
		return if (workers.get(worker) === TestJob.NONE) {
			worker.startJob(job) => [
				thenRunAsync[workers.replace(worker, TestJob.NONE)]
			]
		} else {
			//TODO throw exception
		}
	}
	
	override cancel(RestWorkerClient worker) {
		if (workers.containsKey(worker)) {
			worker.cancel
		} else {
			throw new NoSuchWorkerException(worker.uri)
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
		
	override addWorker(RestWorkerClient worker) {
		workers.put(worker, TestJob.NONE)
	}
	
}
