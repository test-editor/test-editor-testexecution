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
	@Inject @Delegate(TestJobStore) WritableTestJobStore jobStore
	
	var Optional<TestExecutionKey> currentJob = Optional.empty

	override cancelJob(TestExecutionKey key) {
		currentJob.filter[it == key].ifPresent[
			workers.head.cancel
			currentJob = Optional.empty
			jobLog.computeIfPresent(key)[__, job|job.setState(JobState.COMPLETED)]
		]
	}

	override addJob(TestJob it) {
		jobLog.put(id, it)
		workers.head.assign(it)
		currentJob = Optional.of(id)
	}
	
	override boolean testJobExists(TestExecutionKey key) {
		jobLog.computeIfAbsent(key)[
			
		] !== TestJob.NONE
	}

}
