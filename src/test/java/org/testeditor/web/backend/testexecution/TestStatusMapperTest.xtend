package org.testeditor.web.backend.testexecution

import org.junit.Test
import org.testeditor.web.backend.testexecution.manager.TestStatusManager

import static org.assertj.core.api.Assertions.*
import static org.mockito.Mockito.*
import static org.testeditor.web.backend.testexecution.TestStatus.*
import org.testeditor.web.backend.testexecution.manager.WorkerClient

class TestStatusMapperTest {

	TestStatusMapper statusMapperUnderTest = new TestStatusManager

	extension WorkerMocking = new WorkerMocking

	@Test
	def void addTestRunAddsTestInRunningStatus() {
		// given
		val testKey = new TestExecutionKey('a')
		val worker = mock(WorkerClient).thatIsRunning

		// when
		statusMapperUnderTest.addTestSuiteRun(testKey, worker)

		// then
		assertThat(statusMapperUnderTest.getStatus(testKey)).isEqualTo(RUNNING)
	}

	@Test
	def void addTestRunThrowsExceptionWhenAddingRunningTestTwice() {
		// given
		val firstWorker = mock(WorkerClient).thatIsRunning
		val secondWorker = mock(WorkerClient).thatIsRunning
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, firstWorker)

		// when
		try {
			statusMapperUnderTest.addTestSuiteRun(testKey, secondWorker)
			fail('Expected exception but none was thrown.')
		} // then
		catch (IllegalStateException ex) {
			assertThat(ex.message).isEqualTo('''Job "«testKey»" is still running.'''.toString)
		}

	}

	@Test
	def void addTestRunSetsRunningStatusIfPreviousExecutionTerminated() {
		// given
		val firstWorker = mock(WorkerClient).thatTerminatedSuccessfully
		val secondWorker = mock(WorkerClient).thatIsRunning
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, firstWorker)
		assertThat(statusMapperUnderTest.getStatus(testKey)).isNotEqualTo(RUNNING)

		// when
		statusMapperUnderTest.addTestSuiteRun(testKey, secondWorker)

		// then
		assertThat(statusMapperUnderTest.getStatus(testKey)).isEqualTo(RUNNING)
	}

	@Test
	def void getStatusReturnsIdleForUnknownTestKey() {
		// given
		val testKey = new TestExecutionKey('a')

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void getStatusReturnsRunningAsLongAsTestProcessIsAlive() {
		// given
		val worker = mock(WorkerClient).thatIsRunning
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, worker)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.RUNNING)
	}

	@Test
	def void getStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val worker = mock(WorkerClient).thatTerminatedSuccessfully
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, worker)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void getStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(WorkerClient).thatTerminatedWithAnError
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsIdleForUnknownTestKey() {
		// given
		val testKey = new TestExecutionKey('a')

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void waitForStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val worker = mock(WorkerClient).thatTerminatedSuccessfully
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, worker)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void waitForStatusReturnsFailureAfterTestFailed() {
		// given
		val worker = mock(WorkerClient).thatTerminatedWithAnError
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, worker)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getAllInitiallyReturnsEmptyArray() {
		// given + when
		val actualStatuses = statusMapperUnderTest.allTestSuites

		// then
		assertThat(actualStatuses).isEmpty()
	}

	@Test
	def void getAllReturnsStatusOfAllTestsWithKnownStatus() {
		// given
		val failedTestKey = new TestExecutionKey('f')
		val failedWorker = mock(WorkerClient).thatTerminatedWithAnError

		val successfulTestKey = new TestExecutionKey('s')
		val successfulWorker = mock(WorkerClient).thatTerminatedSuccessfully

		val runningTestKey = new TestExecutionKey('r')
		val runningWorker = mock(WorkerClient).thatIsRunning

		statusMapperUnderTest.addTestSuiteRun(failedTestKey, failedWorker)
		statusMapperUnderTest.addTestSuiteRun(successfulTestKey, successfulWorker)
		statusMapperUnderTest.addTestSuiteRun(runningTestKey, runningWorker)

		// when
		val actualStatuses = statusMapperUnderTest.allTestSuites

		// then
		assertThat(actualStatuses).containsOnly(#[
			new TestSuiteStatusInfo => [
				key = failedTestKey
				status = 'FAILED'
			],
			new TestSuiteStatusInfo => [
				key = successfulTestKey
				status = 'SUCCESS'
			],
			new TestSuiteStatusInfo => [
				key = runningTestKey
				status = 'RUNNING'
			]
		])
	}

}
