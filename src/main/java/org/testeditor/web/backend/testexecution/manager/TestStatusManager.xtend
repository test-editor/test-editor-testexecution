package org.testeditor.web.backend.testexecution.manager

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import javax.inject.Singleton
import org.testeditor.web.backend.testexecution.TestExecutionException
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestProcess
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.TestStatusMapper
import org.testeditor.web.backend.testexecution.TestSuiteStatusInfo
import org.testeditor.web.backend.testexecution.UnresponsiveTestProcessException

import static org.testeditor.web.backend.testexecution.TestStatus.*
import org.testeditor.web.backend.testexecution.worker.Worker

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
class TestStatusManager implements TestStatusMapper {
	private static val TIMEOUT_MILLIS = 2000

	public static val TEST_STATUS_MAP_NAME = "testStatusMap"

	var AtomicLong runningTestSuiteRunId = new AtomicLong(0)

	val suiteStatusMap = new ConcurrentHashMap<TestExecutionKey, Worker>

	override TestExecutionKey deriveFreshRunId(TestExecutionKey suiteKey) {
		return suiteKey.deriveWithSuiteRunId(Long.toString(runningTestSuiteRunId.andIncrement))
	}

	override TestStatus getStatus(TestExecutionKey executionKey) {
		if (suiteStatusMap.containsKey(executionKey)) {
			return suiteStatusMap.get(executionKey).checkStatus
		} else {
			return IDLE
		}
	}

	override TestStatus waitForStatus(TestExecutionKey executionKey) {
		if (executionKey.presentOrGetsInsertedBeforeTimeout) {
			return suiteStatusMap.get(executionKey).waitForStatus
		} else {
			return IDLE
		}
	}

	override void addTestSuiteRun(Worker worker, Process runningTestSuite) {
		addTestSuiteRun(worker, runningTestSuite)[]
	}

	override void addTestSuiteRun(Worker worker, Process runningTestSuite, (TestStatus)=>void onCompleted) {
		if (worker.job.isRunning) {
			throw new IllegalStateException('''TestSuite "«worker.job»" is still running.''')
		} else synchronized (this) {
			suiteStatusMap.put(worker.job, worker)
			notifyAll
		}
	}

	override Iterable<TestSuiteStatusInfo> getAllTestSuites() {
		// iterating should be thread-safe, see e.g.
		// https://stackoverflow.com/questions/3768554/is-iterating-concurrenthashmap-values-thread-safe
		return this.suiteStatusMap.entrySet.map [ entry |
			new TestSuiteStatusInfo => [
				key = entry.key
				status = entry.value.checkStatus.name
			]
		]
	}
	
	override void terminateTestSuiteRun(TestExecutionKey testExecutionKey) {
		val testProcess = this.suiteStatusMap.get(testExecutionKey)
		try {
			testProcess.kill
		} catch (UnresponsiveTestProcessException ex) {
			throw new TestExecutionException('Failed to terminate test execution', ex, testExecutionKey)
		}
		
	}

	private def boolean isRunning(TestExecutionKey executionKey) {
		val worker = suiteStatusMap.get(executionKey)
		return worker?.checkStatus == RUNNING
	}
	
	private def synchronized boolean isPresentOrGetsInsertedBeforeTimeout(TestExecutionKey key) {
		var timeElapsed = 0L
		val startTime = System.currentTimeMillis
		while (!suiteStatusMap.containsKey(key) && timeElapsed < TIMEOUT_MILLIS) {
			try {
				wait(TIMEOUT_MILLIS-timeElapsed)
				timeElapsed = System.currentTimeMillis - startTime
			} catch (InterruptedException ex) {
				Thread.currentThread.interrupt
			}
		}
		return suiteStatusMap.containsKey(key)
	}

}
