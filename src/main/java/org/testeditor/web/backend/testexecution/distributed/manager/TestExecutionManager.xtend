package org.testeditor.web.backend.testexecution.distributed.manager

import java.util.Optional
import javax.inject.Inject
import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Delegate
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo.JobState
import org.testeditor.web.backend.testexecution.distributed.common.TestJobStore
import org.testeditor.web.backend.testexecution.distributed.common.WritableTestJobStore

interface TestExecutionManager extends TestJobStore {

	def void cancelJob(TestExecutionKey key)

	def void addJob(TestJob job)

}

@Singleton
class LocalSingleWorkerExecutionManager implements TestExecutionManager {
	@Inject extension WorkerProvider workerProvider
	@Inject extension WritableTestJobStore jobStore
	
	var Optional<TestJobInfo> currentJob = Optional.empty

	override cancelJob(TestExecutionKey key) {
		currentJob.filter[id == key].ifPresent[
			workers.head.cancel
			setState(JobState.COMPLETED).store
			currentJob = Optional.empty
		]
	}

	override addJob(TestJob it) {
		store
		workers.head.assign(it)
		currentJob = Optional.of(it)
	}
	
	override testJobExists(TestExecutionKey key) {
		jobStore.testJobExists(key) || workerProvider.testJobExists(key)
	}
	
	override getJsonCallTree(TestExecutionKey key) {
		jobStore.getJsonCallTree(key).or[workerProvider.getJsonCallTree(key)]
	}
	
}
