package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.AbstractModule
import org.testeditor.web.backend.testexecution.distributed.common.TestExecutionManager
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.common.WritableStatusAwareTestJobStore
import org.testeditor.web.backend.testexecution.distributed.manager.DefaultExecutionManager
import org.testeditor.web.backend.testexecution.distributed.manager.LocalSingleWorkerJobStore
import org.testeditor.web.backend.testexecution.distributed.manager.LocalSingleWorkerManager
import org.testeditor.web.backend.testexecution.distributed.manager.WorkerProvider
import org.testeditor.web.backend.testexecution.distributed.worker.LocalSingleWorker

class RestWorkerModule extends AbstractModule {
	override protected configure() {
		binder => [
			bind(TestExecutionManager).to(DefaultExecutionManager)
			bind(WorkerProvider).to(LocalSingleWorkerManager)
			bind(Worker).to(LocalSingleWorker)
			bind(WritableStatusAwareTestJobStore).to(LocalSingleWorkerJobStore)
		]
	}
}
