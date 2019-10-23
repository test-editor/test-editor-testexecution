package org.testeditor.web.backend.testexecution.distributed.manager

import java.util.Optional
import java.util.Set
import java.util.concurrent.atomic.AtomicLong
import javax.inject.Inject
import javax.inject.Singleton
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.StatusAwareTestJobStore
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo.JobState
import org.testeditor.web.backend.testexecution.distributed.common.WritableStatusAwareTestJobStore

interface TestExecutionManager extends StatusAwareTestJobStore {

	def void cancelJob(TestExecutionKey key)

	def TestExecutionKey addJob(Iterable<String> testFiles, Set<String> requiredCapabilities)

}

@Singleton
class LocalSingleWorkerExecutionManager implements TestExecutionManager {
	static val logger = LoggerFactory.getLogger(LocalSingleWorkerExecutionManager)
	
	@Inject extension WorkerProvider workerProvider
	@Inject extension WritableStatusAwareTestJobStore jobStore
	
	var AtomicLong runningTestSuiteRunId = new AtomicLong(0)
	var Optional<TestJobInfo> currentJob = Optional.empty

	override cancelJob(TestExecutionKey key) {
		currentJob.filter[id == key].ifPresent[
			workers.head.cancel
			setState(JobState.COMPLETED_CANCELLED).store
			currentJob = Optional.empty
		]
	}

	override addJob(Iterable<String> testFiles, Set<String> requiredCapabilities) {
		return (new TestJob(new TestExecutionKey("0").deriveFreshRunId, emptySet, testFiles) => [
			store
			workers.head.assign(it).thenAccept[status|updateStatus(status)]
			currentJob = Optional.of(it)			
		]).id
	}
	
	override testJobExists(TestExecutionKey key) {
		jobStore.testJobExists(key) || workerProvider.testJobExists(key)
	}
	
	override getJsonCallTree(TestExecutionKey key) {
		jobStore.getJsonCallTree(key).or[workerProvider.getJsonCallTree(key)]
	}
	
	override getStatus(TestExecutionKey key) {
		return workerProvider.testJobExists(key) ? workerProvider.getStatus(key) : jobStore.getStatus(key) 
	}
	
	override waitForStatus(TestExecutionKey key) {
		return workerProvider.testJobExists(key) ? workerProvider.waitForStatus(key) : jobStore.waitForStatus(key)
	}
	
	private def TestExecutionKey deriveFreshRunId(TestExecutionKey suiteKey) {
		return suiteKey.deriveWithSuiteRunId(Long.toString(runningTestSuiteRunId.andIncrement))
	}
	
	override getStatusAll() {
		return jobStore.statusAll + workerProvider.statusAll
	}
	
	private def updateStatus(TestJobInfo job, TestStatus status) {
		switch(status) {
			case FAILED: job.setState(JobState.COMPLETED_WITH_ERROR)
			case SUCCESS: job.setState(JobState.COMPLETED_SUCCESSFULLY)
			default: {
				logger.error('''expected status after completion of job with id "«job.id»" to be either "SUCCESS" or "FAILED", but got "«status»"''')
				job
			} 
		}.store
	}
	
}
