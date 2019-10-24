package org.testeditor.web.backend.testexecution.distributed.manager

import javax.inject.Inject
import org.eclipse.xtend.lib.annotations.Delegate
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.TestJobStore
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo

class LocalSingleWorkerManager implements WorkerProvider {

	@Inject @Delegate(TestJobStore) Worker worker
	var TestJobInfo currentJob = null

	override getWorkers() {
		return #[worker.id]
	}
	
	override idleWorkers() {
		return #[worker].filter[checkStatus !== TestStatus.RUNNING].map[uri.toString]
	}
	
	override workerForJob(TestExecutionKey jobId) {
		return if (currentJob?.id == jobId) { worker.id } else { WorkerInfo.NONE.id }
	}

	override assign(String workerId, TestJobInfo job) {
		return if (workerId == this.worker.id) {
			this.worker.startJob(job) => [
				currentJob = job
			]
		} else {
			throw new NoSuchWorkerException(workerId)
		}
	}

	override cancel(String workerId) {
		if (workerId == this.worker.id) {
			this.worker.kill
			currentJob = null
		}
	}

	override getStatus(TestExecutionKey key) {
		return this.worker.checkStatus
	}

	override waitForStatus(TestExecutionKey key) {
		return this.worker.waitForStatus
	}

	override getStatusAll() {
		return #{currentJob.id -> worker.checkStatus}
	}

}
