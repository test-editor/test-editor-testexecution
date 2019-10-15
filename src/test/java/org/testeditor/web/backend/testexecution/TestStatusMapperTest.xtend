package org.testeditor.web.backend.testexecution

import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import org.junit.Test
import org.testeditor.web.backend.testexecution.common.TestExecutionKey

import static org.assertj.core.api.Assertions.*
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*
import static org.testeditor.web.backend.testexecution.TestStatus.*

class TestStatusMapperTest {

	static val EXIT_SUCCESS = 0;
	static val EXIT_FAILURE = 1;

	TestStatusMapper statusMapperUnderTest = new TestStatusMapper
	
	extension TestProcessMocking = new TestProcessMocking

	@Test
	def void addTestRunAddsTestInRunningStatus() {
		// given
		val testProcess = mock(Process).thatIsRunning
		testProcess.mockHandle(true)
		val testKey = new TestExecutionKey('a')

		// when
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// then
		assertThat(statusMapperUnderTest.getStatus(testKey)).isEqualTo(RUNNING)
	}

	@Test
	def void addTestRunThrowsExceptionWhenAddingRunningTestTwice() {
		// given
		val testProcess = mock(Process).thatIsRunning
		val secondProcess = mock(Process).thatIsRunning
		testProcess.mockHandle(true)
		secondProcess.mockHandle(true)
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		try {
			statusMapperUnderTest.addTestSuiteRun(testKey, secondProcess)
			fail('Expected exception but none was thrown.')
		} // then
		catch (IllegalStateException ex) {
			assertThat(ex.message).isEqualTo('''TestSuite "«testKey»" is still running.'''.toString)
		}

	}

	@Test
	def void addTestRunSetsRunningStatusIfPreviousExecutionTerminated() {
		// given
		val testProcess = mock(Process).thatTerminatedSuccessfully => [ mockHandle(false) ]
		val secondProcess = mock(Process).thatIsRunning => [ mockHandle(true) ]
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)
		assertThat(statusMapperUnderTest.getStatus(testKey)).isNotEqualTo(RUNNING)

		// when
		statusMapperUnderTest.addTestSuiteRun(testKey, secondProcess)

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
		val testProcess = mock(Process).thatIsRunning => [ mockHandle(true) ]
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.RUNNING)
	}

	@Test
	def void getStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val testProcess = mock(Process).thatTerminatedSuccessfully => [ mockHandle(false) ]
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void getStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(Process).thatTerminatedWithAnError => [ mockHandle(false) ]
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.getStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)
		testProcess.waitFor

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
	def void waitForStatusCallsBlockingWaitForMethodOfProcess() {
		// given
		val testProcess = mock(Process).thatIsRunning
		val future = testProcess.mockHandle(true).mockFuture(false)
		val testKey = new TestExecutionKey('a')

		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		statusMapperUnderTest.waitForStatus(testKey)

		// then
		verify(future).get(5, TimeUnit.SECONDS)
	}

	@Test
	def void waitForStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val testProcess = mock(Process).thatTerminatedWithExitCode(EXIT_SUCCESS) => [ mockHandle(false) ]
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void waitForStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(Process).thatTerminatedWithExitCode(EXIT_FAILURE) => [ mockHandle(false) ]
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

		// when
		val actualStatus = statusMapperUnderTest.waitForStatus(testKey)

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		val testKey = new TestExecutionKey('a')
		statusMapperUnderTest.addTestSuiteRun(testKey, testProcess)

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
		val failedProcess = mock(Process).thatTerminatedWithExitCode(EXIT_FAILURE) => [ mockHandle(false) ]

		val successfulTestKey = new TestExecutionKey('s')
		val successfulProcess = mock(Process).thatTerminatedWithExitCode(EXIT_SUCCESS) => [ mockHandle(false) ]

		val runningTestKey = new TestExecutionKey('r')
		val runningProcess = mock(Process).thatIsRunning => [ mockHandle(true) ]

		statusMapperUnderTest.addTestSuiteRun(failedTestKey, failedProcess)
		statusMapperUnderTest.addTestSuiteRun(successfulTestKey, successfulProcess)
		statusMapperUnderTest.addTestSuiteRun(runningTestKey, runningProcess)

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
	
	@Test
	def void terminateTestSuiteRunKillsAssociatedProcess() {
		// given
		val testSuiteKey = new TestExecutionKey('running')
		val runningProcess = mockedRunningThenKilledProcess()
		statusMapperUnderTest.addTestSuiteRun(testSuiteKey, runningProcess)

		// when
		statusMapperUnderTest.terminateTestSuiteRun(testSuiteKey)

		// then
		verify(runningProcess.toHandle).destroy
	}
	
	@Test
	def void terminateTestSuiteRunSetsStatusToFailed() {
		// given
		val testSuiteKey = new TestExecutionKey('running')
		val runningProcess = mockedRunningThenKilledProcess
		statusMapperUnderTest.addTestSuiteRun(testSuiteKey, runningProcess)

		// when
		statusMapperUnderTest.terminateTestSuiteRun(testSuiteKey)

		// then
		assertThat(statusMapperUnderTest.getStatus(testSuiteKey)).isEqualTo(TestStatus.FAILED)
	}
	
	@Test
	def void terminateTestSuiteRunThrowsExceptionIfProcessWontDie() {
		// given
		val testSuiteKey = new TestExecutionKey('running')
		val runningProcess = mockedRunningProcessThatWontDie
		statusMapperUnderTest.addTestSuiteRun(testSuiteKey, runningProcess)

		// when
		try {
			statusMapperUnderTest.terminateTestSuiteRun(testSuiteKey)

		// then
			fail('expected TestExecutionException to be thrown')
		} catch (TestExecutionException ex) {
			assertThat(ex.message).isEqualTo('Failed to terminate test execution')
			assertThat(ex.cause).isInstanceOf(UnresponsiveTestProcessException)
			assertThat(ex.key).isEqualTo(testSuiteKey)
		}
	}

	def private mockedTerminatedProcess(int exitCode) {
		val testProcess = mock(Process)
		when(testProcess.exitValue).thenReturn(exitCode)
		when(testProcess.waitFor).thenReturn(exitCode)
		when(testProcess.alive).thenReturn(false)
		return testProcess
	}

	def private mockedRunningProcess() {
		val testProcess = mock(Process)
		when(testProcess.exitValue).thenThrow(new IllegalStateException("Process is still running"))
		when(testProcess.waitFor).thenReturn(0)
		when(testProcess.alive).thenReturn(true)
		return testProcess
	}
	
	def private mockedRunningProcessThatWontDie() {
		val testProcess = mockedRunningProcess
		testProcess.addProcessHandle.thatWontDie
		when(testProcess.destroyForcibly).thenReturn(testProcess)
		when(testProcess.waitFor(anyLong, any(TimeUnit))).thenReturn(false)
		return testProcess
	}
	
	def private addProcessHandle(Process process) {
		return mock(ProcessHandle) => [
			when(process.toHandle).thenReturn(it)
		]
	}
	
	def private void thatWontDie(ProcessHandle processHandle) {
		val processFuture = mock(CompletableFuture)
		when(processFuture.get(anyLong, eq(TimeUnit.SECONDS))).thenThrow(TimeoutException)
		when(processHandle.onExit).thenReturn(processFuture)
	}
	
	def private mockedRunningThenKilledProcess() {
		val testProcess = mock(Process)
		testProcess.addProcessHandle.thatHasTerminated
		when(testProcess.exitValue).thenReturn(129)
		when(testProcess.waitFor).thenReturn(129)
		when(testProcess.alive).thenReturn(true, false)
		when(testProcess.waitFor(TestSuiteResource.LONG_POLLING_TIMEOUT_SECONDS, TimeUnit.SECONDS)).thenReturn(true)
		return testProcess
	}
	
	def private void thatHasTerminated(ProcessHandle processHandle) {
		val processFuture = mock(CompletableFuture)
		when(processFuture.get(anyLong, eq(TimeUnit.SECONDS))).thenReturn(processHandle)
		when(processHandle.onExit).thenReturn(processFuture)
	}

}
