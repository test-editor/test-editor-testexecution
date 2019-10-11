package org.testeditor.web.backend.testexecution.distributed.manager

import javax.inject.Inject
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.common.WorkerInfo

class LocalSingleWorkerManager implements WorkerProvider {

	@Inject Worker worker

	override getWorkers() {
		return #[worker]
	}

	override assign(WorkerInfo worker, TestJob job) {
		if (worker === this.worker) {
			this.worker.startJob(job).toCompletableFuture.get
		}
	}

	override cancel(WorkerInfo worker) {
		if (worker === this.worker) {
			this.worker.kill
		}
	}

}
