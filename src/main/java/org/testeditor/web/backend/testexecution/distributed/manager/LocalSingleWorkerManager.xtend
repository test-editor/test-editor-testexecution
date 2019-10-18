package org.testeditor.web.backend.testexecution.distributed.manager

import javax.inject.Inject
import org.eclipse.xtend.lib.annotations.Delegate
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.TestJobStore
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo

class LocalSingleWorkerManager implements WorkerProvider {

	@Inject @Delegate(TestJobStore) Worker worker
	var TestJobInfo currentJob = null

	override getWorkers() {
		return #[worker]
	}

	override assign(WorkerInfo worker, TestJob job) {
		return if (worker === this.worker) {
			this.worker.startJob(job) => [
				currentJob = job
			]
		} else {
			//TODO throw exception
		}
	}

	override cancel(WorkerInfo worker) {
		if (worker === this.worker) {
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
