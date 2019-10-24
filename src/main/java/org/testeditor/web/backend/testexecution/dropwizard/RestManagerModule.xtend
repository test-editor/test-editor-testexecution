package org.testeditor.web.backend.testexecution.dropwizard

import com.google.inject.AbstractModule
import com.google.inject.TypeLiteral
import org.testeditor.web.backend.testexecution.distributed.common.TestExecutionManager
import org.testeditor.web.backend.testexecution.distributed.common.WritableStatusAwareTestJobStore
import org.testeditor.web.backend.testexecution.distributed.manager.DefaultExecutionManager
import org.testeditor.web.backend.testexecution.distributed.manager.LocalSingleWorkerJobStore
import org.testeditor.web.backend.testexecution.distributed.manager.WorkerProvider
import org.testeditor.web.backend.testexecution.distributed.manager.WritableWorkerProvider
import org.testeditor.web.backend.testexecution.distributed.manager.rest.RestWorkerClient
import org.testeditor.web.backend.testexecution.distributed.manager.rest.RestWorkerManager

class RestManagerModule extends AbstractModule {

	override protected configure() {

		binder => [
			bind(TestExecutionManager).to(DefaultExecutionManager)
			bind(WorkerProvider).to(RestWorkerManager)
			bind(WritableStatusAwareTestJobStore).to(LocalSingleWorkerJobStore)
			bind(new TypeLiteral<WritableWorkerProvider<RestWorkerClient>>(){}).to(RestWorkerManager)
		]

	}

}
