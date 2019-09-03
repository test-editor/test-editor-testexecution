package org.testeditor.web.backend.testexecution

import java.net.URI
import java.util.Set
import java.util.concurrent.CompletableFuture
import org.eclipse.xtend.lib.annotations.Accessors
import org.testeditor.web.backend.testexecution.manager.TestJobInfo
import org.testeditor.web.backend.testexecution.worker.OperableWorker
import org.testeditor.web.backend.testexecution.worker.Worker

import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.*
import static org.testeditor.web.backend.testexecution.TestStatus.*

class WorkerMocking {

	def Worker thatIsRunning(Worker mockWorker) {
		return mockWorker => [
			when(checkStatus).thenReturn(TestStatus.RUNNING)
			when(waitForStatus).thenReturn(TestStatus.RUNNING)
		]
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

	def Worker thatIsIdle(Worker mockWorker) {
		return mockWorker => [
			when(checkStatus).thenReturn(TestStatus.IDLE)
			lenient.when(waitForStatus).thenReturn(TestStatus.IDLE)
		]
	}

	def Worker withUri(Worker mockWorker, String uri) {
		return mockWorker => [
			when(getUri).thenReturn(new URI(uri))
		]
	}

	def Worker withCapabilities(Worker mockWorker, String... capabilities) {
		return mockWorker => [
			when(providedCapabilities).thenReturn(newHashSet(capabilities))
		]
	}

	def Worker thatCanBeStarted(Worker mockWorker) {
		return mockWorker => [
			when(startJob(any(TestJobInfo))).thenReturn(CompletableFuture.completedStage(true))
		]
	}

	static class WorkerStub implements OperableWorker {

		@Accessors(PUBLIC_SETTER)
		var TestStatus status

		@Accessors
		var Set<String> providedCapabilities

		@Accessors
		var URI uri

		override checkStatus() {
			return status
		}

		override waitForStatus() {
			return status
		}

		override kill() {
			if (status === RUNNING) {
				status = TestStatus.FAILED
			}
		}

		override startJob(TestJobInfo job) {
			return CompletableFuture.completedStage(transitionToRunning)

		}

		private def boolean transitionToRunning() {
			return (status !== RUNNING) => [ idle |
				if (idle) {
					status = RUNNING
				}
			]
		}

	}

}
