package org.testeditor.web.backend.testexecution.worker

import java.util.Optional
import java.util.concurrent.atomic.AtomicLong
import javax.inject.Singleton
import org.testeditor.web.backend.testexecution.RunningTest
import org.testeditor.web.backend.testexecution.TestExecutionException
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestProcess
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.TestSuiteStatusInfo
import org.testeditor.web.backend.testexecution.UnresponsiveTestProcessException

import static org.testeditor.web.backend.testexecution.TestStatus.*

/**
 * Keeps a record of running tests and their current execution status.
 * 
 * CURRENTLY KEEPS TRACK OF TESTS AND TEST SUITES. TEST SUITES WILL HOPEFULLY 
 * PERVAIL, (SINGLE) TEST RUNS WILL BECOME SPECIALIZED TEST SUITES
 * 
 * Test processes are added to the record using 
 * {@link #addTestRun(String, Process) addTestRun}. It is an error to add a test
 * process while a previous run has not yet terminated.
 * 
 * The current status of a test process can be retrieved with
 * {@link #getStatus(String) getStatus}. By default (including if no record of
 * an execution of the respective test is present), the result will be IDLE, 
 * otherwise the status corresponds to that of the external process running the
 * test: either it is still running, has completed successfully, or failed.
 * 
 * Alternatively, {@link #waitForStatus(String) waitForStatus} will block if the
 * test is still being executed, and in that case will only return once the
 * external process has terminated.
 * 
 * To keep a record of current and past test executions, this class relies on
 * class {@link TestProcess TestProcess}, 
 * which also takes care of removing references to 
 * {@link Process Process} classes once they have terminated.
 */
@Singleton
class WorkerStatusManager {

	public static val String TEST_STATUS_MAP_NAME = "testStatusMap"

	var AtomicLong runningTestSuiteRunId = new AtomicLong(0)

	var RunningTest _currentJob

	def TestExecutionKey deriveFreshRunId(TestExecutionKey suiteKey) {
		return suiteKey.deriveWithSuiteRunId(Long.toString(runningTestSuiteRunId.andIncrement))
	}
	
	private def Optional<RunningTest> getCurrentJob() {
		return Optional.ofNullable(_currentJob)
	}
	
	private def void setCurrentJob(RunningTest job) {
		this._currentJob = job
	}

	def TestStatus getStatus() {
		return currentJob.map[checkStatus].orElse(IDLE)
	}

	def TestStatus waitForStatus() {
		return currentJob.map[waitForStatus].orElse(IDLE)
	}

	def void addTestSuiteRun(Process runningTestSuite) {
		addTestSuiteRun(runningTestSuite)[]
	}

	def void addTestSuiteRun(Process runningTestSuite, (TestStatus)=>void onCompleted) {
		val status = currentJob.map[checkStatus]
		val running = status.filter[it === RUNNING]
		running.ifPresentOrElse([
			throw new IllegalStateException('''Worker is busy.''')
		],[
			currentJob = new TestProcess(runningTestSuite, onCompleted)
		])
	}
	
	def void terminateTestSuiteRun() {
		try {
			currentJob.ifPresent[kill]
		} catch (UnresponsiveTestProcessException ex) {
			throw new TestExecutionException('Failed to terminate test execution', ex)
		}
		
	}

}
