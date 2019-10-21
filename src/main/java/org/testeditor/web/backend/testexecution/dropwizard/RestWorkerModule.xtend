package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.AbstractModule
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.distributed.worker.LocalSingleWorker

class RestWorkerModule extends AbstractModule {
	override protected configure() {
		binder => [
			bind(Worker).to(LocalSingleWorker)
		]
	}
}
