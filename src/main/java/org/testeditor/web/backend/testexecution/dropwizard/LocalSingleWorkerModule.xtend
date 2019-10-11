package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.AbstractModule
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.manager.LocalSingleWorkerExecutionManager
import org.testeditor.web.backend.testexecution.distributed.manager.LocalSingleWorkerManager
import org.testeditor.web.backend.testexecution.distributed.manager.TestExecutionManager
import org.testeditor.web.backend.testexecution.distributed.manager.WorkerProvider
import org.testeditor.web.backend.testexecution.distributed.worker.LocalSingleWorker

class LocalSingleWorkerModule extends AbstractModule {
	override protected configure() {
		binder => [
			bind(TestExecutionManager).to(LocalSingleWorkerExecutionManager)
			bind(WorkerProvider).to(LocalSingleWorkerManager)
			bind(Worker).to(LocalSingleWorker)
		]
	}
}
