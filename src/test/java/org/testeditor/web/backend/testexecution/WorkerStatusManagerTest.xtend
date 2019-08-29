package org.testeditor.web.backend.testexecution

import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import org.junit.Test
import org.testeditor.web.backend.testexecution.worker.WorkerStatusManager

import static org.assertj.core.api.Assertions.*
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*
import static org.testeditor.web.backend.testexecution.TestStatus.*

class WorkerStatusManagerTest {

	static val EXIT_SUCCESS = 0;
	static val EXIT_FAILURE = 1;

	val workerStatusManager = new WorkerStatusManager
	
	extension TestProcessMocking = new TestProcessMocking

	@Test
	def void addTestRunAddsTestInRunningStatus() {
		// given
		val testProcess = mock(Process).thatIsRunning
		testProcess.mockHandle(true)
		val testKey = new TestExecutionKey('a')

		// when
		workerStatusManager.addTestSuiteRun(testProcess)

		// then
		assertThat(workerStatusManager.getStatus).isEqualTo(RUNNING)
	}

	@Test
	def void addTestRunThrowsExceptionWhenAddingRunningTestTwice() {
		// given
		val testProcess = mock(Process).thatIsRunning
		val secondProcess = mock(Process).thatIsRunning
		testProcess.mockHandle(true)
		secondProcess.mockHandle(true)
		workerStatusManager.addTestSuiteRun(testProcess)

		// when
		try {
			workerStatusManager.addTestSuiteRun(secondProcess)
			fail('Expected exception but none was thrown.')
		} // then
		catch (IllegalStateException ex) {
			assertThat(ex.message).isEqualTo('Worker is busy.')
		}

	}

	@Test
	def void addTestRunSetsRunningStatusIfPreviousExecutionTerminated() {
		// given
		val testProcess = mock(Process).thatTerminatedSuccessfully => [ mockHandle(false) ]
		val secondProcess = mock(Process).thatIsRunning => [ mockHandle(true) ]
		workerStatusManager.addTestSuiteRun(testProcess)
		assertThat(workerStatusManager.getStatus).isNotEqualTo(RUNNING)

		// when
		workerStatusManager.addTestSuiteRun(secondProcess)

		// then
		assertThat(workerStatusManager.getStatus).isEqualTo(RUNNING)
	}

	@Test
	def void getStatusReturnsIdleIfNothingWasAdded() {
		// given + when
		val actualStatus = workerStatusManager.getStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void getStatusReturnsRunningAsLongAsTestProcessIsAlive() {
		// given
		val testProcess = mock(Process).thatIsRunning => [ mockHandle(true) ]
		workerStatusManager.addTestSuiteRun(testProcess)

		// when
		val actualStatus = workerStatusManager.getStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.RUNNING)
	}

	@Test
	def void getStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val testProcess = mock(Process).thatTerminatedSuccessfully => [ mockHandle(false) ]
		workerStatusManager.addTestSuiteRun(testProcess)

		// when
		val actualStatus = workerStatusManager.getStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void getStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(Process).thatTerminatedWithAnError => [ mockHandle(false) ]
		workerStatusManager.addTestSuiteRun(testProcess)

		// when
		val actualStatus = workerStatusManager.getStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void getStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		workerStatusManager.addTestSuiteRun(testProcess)
		testProcess.waitFor

		// when
		val actualStatus = workerStatusManager.getStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsIdleIfNothingWasAdded() {
		// given + when
		val actualStatus = workerStatusManager.waitForStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.IDLE)
	}

	@Test
	def void waitForStatusCallsBlockingWaitForMethodOfProcess() {
		// given
		val testProcess = mock(Process).thatIsRunning
		val future = testProcess.mockHandle(true).mockFuture(false)

		workerStatusManager.addTestSuiteRun(testProcess)

		// when
		workerStatusManager.waitForStatus

		// then
		verify(future).get(5, TimeUnit.SECONDS)
	}

	@Test
	def void waitForStatusReturnsSuccessAfterTestFinishedSuccessfully() {
		// given
		val testProcess = mock(Process).thatTerminatedWithExitCode(EXIT_SUCCESS) => [ mockHandle(false) ]
		workerStatusManager.addTestSuiteRun(testProcess)

		// when
		val actualStatus = workerStatusManager.waitForStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.SUCCESS)
	}

	@Test
	def void waitForStatusReturnsFailureAfterTestFailed() {
		// given
		val testProcess = mock(Process).thatTerminatedWithExitCode(EXIT_FAILURE) => [ mockHandle(false) ]
		workerStatusManager.addTestSuiteRun(testProcess)

		// when
		val actualStatus = workerStatusManager.waitForStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}

	@Test
	def void waitForStatusReturnsFailureWhenExternalProcessExitsWithNoneZeroCode() {
		// given
		val testProcess = new ProcessBuilder('sh', '-c', '''exit «EXIT_FAILURE»''').start
		workerStatusManager.addTestSuiteRun(testProcess)

		// when
		val actualStatus = workerStatusManager.waitForStatus

		// then
		assertThat(actualStatus).isEqualTo(TestStatus.FAILED)
	}
	
	@Test
	def void terminateTestSuiteRunKillsAssociatedProcess() {
		// given
		val runningProcess = mockedRunningThenKilledProcess()
		workerStatusManager.addTestSuiteRun(runningProcess)

		// when
		workerStatusManager.terminateTestSuiteRun

		// then
		verify(runningProcess.toHandle).destroy
	}
	
	@Test
	def void terminateTestSuiteRunSetsStatusToFailed() {
		// given
		val runningProcess = mockedRunningThenKilledProcess
		workerStatusManager.addTestSuiteRun(runningProcess)

		// when
		workerStatusManager.terminateTestSuiteRun

		// then
		assertThat(workerStatusManager.getStatus).isEqualTo(TestStatus.FAILED)
	}
	
	@Test
	def void terminateTestSuiteRunThrowsExceptionIfProcessWontDie() {
		// given
		val runningProcess = mockedRunningProcessThatWontDie
		workerStatusManager.addTestSuiteRun(runningProcess)

		// when
		try {
			workerStatusManager.terminateTestSuiteRun

		// then
			fail('expected TestExecutionException to be thrown')
		} catch (TestExecutionException ex) {
			assertThat(ex.message).isEqualTo('Failed to terminate test execution')
			assertThat(ex.cause).isInstanceOf(UnresponsiveTestProcessException)
		}
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
