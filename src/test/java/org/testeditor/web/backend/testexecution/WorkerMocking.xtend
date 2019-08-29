package org.testeditor.web.backend.testexecution

import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeoutException
import java.util.stream.Stream
import org.testeditor.web.backend.testexecution.worker.Worker

import static java.util.concurrent.TimeUnit.SECONDS
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*

class WorkerMocking {

	def Worker thatIsRunning(Worker mockWorker) {
		return mockWorker => [
			when(checkStatus).thenReturn(TestStatus.RUNNING)
			when(waitForStatus).thenReturn(TestStatus.RUNNING)
		]
	}

	def Process thatIsRunningAndThenForciblyDestroyed(Process mockProcess) {
		val processHandle = mock(ProcessHandle)
		val processFuture = mock(CompletableFuture)
		when(processFuture.get(anyLong, eq(SECONDS))).thenReturn(processHandle)
		when(processHandle.onExit).thenReturn(processFuture)
		when(mockProcess.toHandle).thenReturn(processHandle)

		when(mockProcess.alive).thenReturn(true, false)
		when(mockProcess.destroyForcibly).thenReturn(mockProcess)
		when(mockProcess.exitValue).thenReturn(129)
		when(mockProcess.waitFor(1, SECONDS)).thenReturn(true)

		return mockProcess
	}

	def Process thatIsRunningAndWontDie(Process mockProcess) {
		val processHandle = mock(ProcessHandle)
		val processFuture = mock(CompletableFuture)
		when(processFuture.get(anyLong, eq(SECONDS))).thenThrow(TimeoutException)
		when(processHandle.onExit).thenReturn(processFuture)
		when(mockProcess.toHandle).thenReturn(processHandle)

		when(mockProcess.alive).thenReturn(true)
		when(mockProcess.destroyForcibly).thenReturn(mockProcess)
		when(mockProcess.exitValue).thenThrow(new IllegalThreadStateException())
		when(mockProcess.waitFor(1, SECONDS)).thenReturn(false)
		return mockProcess
	}

	def Worker thatTerminatedSuccessfully(Worker mockWorker) {
		return mockWorker => [
			when(checkStatus).thenReturn(TestStatus.SUCCESS)
			when(waitForStatus).thenReturn(TestStatus.SUCCESS)
		]
	}

	def Worker thatTerminatedWithAnError(Worker mockWorker) {
		return mockWorker => [
			when(checkStatus).thenReturn(TestStatus.FAILED)
			when(waitForStatus).thenReturn(TestStatus.FAILED)
		]
	}

	def Process thatTerminatedWithExitCode(Process mockProcess, int exitCode) {
		when(mockProcess.alive).thenReturn(false)
		when(mockProcess.exitValue).thenReturn(exitCode)
		return mockProcess
	}

	def ProcessHandle mockHandle(Process mockProcess, boolean alive) {
		return mock(ProcessHandle) => [ handle |
			when(handle.alive).thenReturn(alive)
			when(mockProcess.toHandle).thenReturn(handle)
			when(mockProcess.descendants).thenAnswer[Stream.empty]
		]
	}

	def CompletableFuture<ProcessHandle> mockFuture(ProcessHandle mockHandle, boolean complete) {
		return mock(CompletableFuture) as CompletableFuture<ProcessHandle> => [ future |
			when(future.get(anyLong, eq(SECONDS))) => [
				if (complete) {
					thenReturn(mockHandle)
				} else {
					thenThrow(TimeoutException)
				}
			]
			when(mockHandle.onExit).thenReturn(future)
		]
	}

}
