package org.testeditor.web.backend.testexecution

import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject
import javax.inject.Provider
import javax.inject.Singleton
import org.testeditor.web.backend.testexecution.common.TestExecutionConfiguration
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.TestJobStatusMapper

import static org.testeditor.web.backend.testexecution.common.TestStatus.*

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
class TestStatusMapper implements TestJobStatusMapper {
	
	@Inject Provider<TestExecutionConfiguration> configProvider

	public static val TEST_STATUS_MAP_NAME = "testStatusMap"

	val suiteStatusMap = new ConcurrentHashMap<TestExecutionKey, TestProcess>
	
	private def longPollingTimeoutSeconds() {
		return configProvider.get.longPollingTimeoutSeconds
	}

	override TestStatus getStatus(TestExecutionKey executionKey) {
		if (suiteStatusMap.containsKey(executionKey)) {
			return suiteStatusMap.get(executionKey).checkStatus
		} else {
			return IDLE
		}
	}

	override TestStatus waitForStatus(TestExecutionKey executionKey) {
		if (suiteStatusMap.containsKey(executionKey)) {
			return suiteStatusMap.get(executionKey).waitForStatus
		} else {
			return IDLE
		}
	}

	def void addTestSuiteRun(TestExecutionKey testExecutionKey, Process runningTestSuite) {
		addTestSuiteRun(testExecutionKey, runningTestSuite)[]
	}

	def void addTestSuiteRun(TestExecutionKey testExecutionKey, Process runningTestSuite, (TestStatus)=>void onCompleted) {
		if (testExecutionKey.isRunning) {
			throw new IllegalStateException('''TestSuite "«testExecutionKey»" is still running.''')
		} else {
			val testProcess = new TestProcess(runningTestSuite, longPollingTimeoutSeconds, onCompleted)
			suiteStatusMap.put(testExecutionKey, testProcess)
		}
	}

	override getStatusAll() {
		// iterating should be thread-safe, see e.g.
		// https://stackoverflow.com/questions/3768554/is-iterating-concurrenthashmap-values-thread-safe
		return suiteStatusMap.mapValues[checkStatus]
	}
	
	def void terminateTestSuiteRun(TestExecutionKey testExecutionKey) {
		val testProcess = this.suiteStatusMap.get(testExecutionKey)
		try {
			testProcess.kill
		} catch (UnresponsiveTestProcessException ex) {
			throw new TestExecutionException('Failed to terminate test execution', ex, testExecutionKey)
		}
		
	}

	private def boolean isRunning(TestExecutionKey executionKey) {
		val process = suiteStatusMap.getOrDefault(executionKey, TestProcess.DEFAULT_IDLE_TEST_PROCESS)
		return process.checkStatus == RUNNING
	}

}
