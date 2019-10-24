package org.testeditor.web.backend.testexecution.distributed.manager.rest

import java.util.Optional
import javax.inject.Singleton
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo
import org.testeditor.web.backend.testexecution.distributed.manager.NoSuchWorkerException
import org.testeditor.web.backend.testexecution.distributed.manager.WritableWorkerProvider

import static org.testeditor.web.backend.testexecution.distributed.common.TestJob.NONE

@Singleton
class RestWorkerManager implements WritableWorkerProvider<RestWorkerClient> {
	
	val workers = <String, RestWorkerClient>newHashMap
	val assignments = <String, TestJobInfo>newHashMap
	
	override getWorkers() {
		return workers.keySet
	}
	
	override idleWorkers() {
		return workers.keySet.filter[unassigned]
	}
	
	override workerForJob(TestJobInfo job) {
		return assignments.keySet.findFirst[assignments.getOrDefault(it, NONE).id == job.id] ?: WorkerInfo.NONE.id
	}
	
	override assign(String it, TestJobInfo job) {
		return if (unassigned) {
			worker.startJob(job) => [whenCompleted|
				assignments.put(it, job)
				whenCompleted.thenRunAsync[assignments.remove(it)]
			]
		} else {
			//TODO throw exception
		}
	}
	
	override cancel(String it) {
		worker.kill
	}
	
	override testJobExists(TestExecutionKey key) {
		return assignments.values.exists[id == key]
	}
	
	override getJsonCallTree(TestExecutionKey key) {
		return key.worker.flatMap[getJsonCallTree(key)]
	}
	
	override getStatusAll() {
		return assignments.filter[__, job| job !== NONE].keySet.toMap([testJob.id],[worker.checkStatus])
	}
	
	override getStatus(TestExecutionKey key) {
		return key.worker.map[checkStatus].orElse(TestStatus.IDLE)
	}
	
	override waitForStatus(TestExecutionKey key) {
		return key.worker.map[waitForStatus].orElse(TestStatus.IDLE)
	}
		
	override addWorker(RestWorkerClient worker) {
		workers.put(worker.id, worker)
	}
	
	private def isUnassigned(String it) {
		testJob === NONE
	}
	
	private def getWorker(TestExecutionKey key) {
		return Optional.ofNullable(assignments.filter[__, job| job.id == key].keySet.head?.worker)
	}
	
	private def getWorker(String workerId) {
		if (workers.containsKey(workerId)) {	
			workers.get(workerId) 	
		} else {
			throw new NoSuchWorkerException(workerId)
		}
	}
	
	private def getTestJob(String workerId) {
		assignments.getOrDefault(workerId, NONE)
	}
	
}
