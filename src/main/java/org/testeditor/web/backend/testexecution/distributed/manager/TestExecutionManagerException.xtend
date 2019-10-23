package org.testeditor.web.backend.testexecution.distributed.manager

import java.net.URI
import org.eclipse.xtend.lib.annotations.Accessors
import org.testeditor.web.backend.testexecution.common.TestExecutionKey

abstract class TestExecutionManagerException extends IllegalStateException {

		new(String message) {
			super(message)
		}

	}

	abstract class WorkerException extends TestExecutionManagerException {

		@Accessors(PUBLIC_GETTER)
		val String workerId

		new(String workerId, String message) {
			super(message)
			this.workerId = workerId
		}

	}

	class AlreadyRegisteredException extends WorkerException {

		new(URI workerUri) {
			super(workerUri.toString, 'worker already registered')
		}

	}

	class NoSuchWorkerException extends WorkerException {

		new(URI missingWorkerUri) {
			super(missingWorkerUri.toString, '''no worker with id "«missingWorkerUri»"''')
		}

	}

	class NoSuchJobException extends TestExecutionManagerException {

		new(TestExecutionKey missingJobId) {
			super('''no job with id "«missingJobId.toString»"''')
		}

	}

	class NoEligibleWorkerException extends TestExecutionManagerException {

		new() {
			super('no registered worker can accept this job, or no workers registered')
		}

	}

	class AlreadyCompletedException extends TestExecutionManagerException {

		new(TestExecutionKey jobId) {
			super('''job "«jobId»" has already been completed''')
		}

	}