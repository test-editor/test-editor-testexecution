package org.testeditor.web.backend.testexecution.distributed.manager

import java.util.Optional
import javax.inject.Inject
import javax.inject.Singleton
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.distributed.common.TestJob

interface TestExecutionManager {

	def void cancelJob(TestExecutionKey key)

	def void addJob(TestJob job)

}

@Singleton
class LocalSingleWorkerExecutionManager implements TestExecutionManager {
	@Inject extension WorkerProvider

	var Optional<TestExecutionKey> currentJob = Optional.empty

	override cancelJob(TestExecutionKey key) {
		currentJob.filter[it == key].ifPresent[
			workers.head.cancel
			currentJob = Optional.empty
		]
	}

	override addJob(TestJob it) {
		workers.head.assign(it)
		currentJob = Optional.of(id)
	}

}
