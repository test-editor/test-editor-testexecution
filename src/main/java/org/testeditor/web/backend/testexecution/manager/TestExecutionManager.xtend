package org.testeditor.web.backend.testexecution.manager

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentMap
import java.util.concurrent.ConcurrentSkipListMap
import java.util.concurrent.ConcurrentSkipListSet
import java.util.concurrent.Executor
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import org.testeditor.web.backend.testexecution.worker.Worker
import java.util.concurrent.ConcurrentLinkedQueue
import javax.ws.rs.core.Response.Status

@Singleton
class TestExecutionManager {
    static val logger = LoggerFactory.getLogger(TestExecutionManager)

	val ConcurrentMap<String, Worker> idleWorkers = new ConcurrentHashMap
	val ConcurrentMap<String, Worker> busyWorkers = new ConcurrentHashMap
	val ConcurrentLinkedQueue<TestJob> pendingJobs = new ConcurrentLinkedQueue 
	val ConcurrentLinkedQueue<TestJob> assignedJobs = new ConcurrentLinkedQueue
	val dispatcher = new Dispatcher(this)

	@Inject
	RestClient client

	@Inject @Named('TestExecutionManagerExecutor')
	Executor executor

	/**
	 * Adds a new worker.
	 * 
	 * If there are pending jobs, the test execution manager will immediately try to assign one to the new worker:
	 * All pending jobs are filtered for the ones that can run on the newly added worker, according to their capabilities.
	 * From this subset of jobs, the one that was enqueued first will be assigned to the worker.
	 */
	def String addWorker(Worker worker) {
		if (worker.isRegistered) {
			throw new AlreadyRegisteredException(worker.id)
		}
		idleWorkers.put(worker.id, worker.copy)
		return worker.id
	}

	/**
	 * Removes a worker.
	 * 
	 * If the worker was idle, nothing else happens.
	 * If the worker was executing its assigned test job, this job will be set to pending again, retaining its original priority:
	 * it will take its place in the queue before all jobs that came in after it, and after all jobs that came in before it.
	 * That means that, if all jobs that were enqueued before it are already assigned or completed, it will become the head of
	 * the pending queue.
	 */
	def void removeWorker(String id) {
		if (idleWorkers.containsKey(id)) {
			idleWorkers.remove(id)
		} else if (busyWorkers.containsKey(id)) {
			busyWorkers.remove(id)
		} else {
			throw new NoSuchWorkerException(id)
		}

	}

	/**
	 * Adds a test job.
	 * 
	 * If there is at least one worker (no matter if it is idle or busy) registered with the test execution manager that can
	 * satisfy its capability requirements, it will be accepted and enqueued as a pending job. Otherwise it will be rejected.
	 * 
	 * If there are idle workers, the test execution manager will immediately try to assign the new job to one of them:
	 * All idle workers are filtered for the ones that can run the newly added job, according to their capabilities.
	 * From this subset of workers, the one with the fewest capabilities is chosen (if there still are multiple options,
	 * the choice among them is arbitrary).
	 */
	def void addJob(TestJob job) {
		if (job.canBeAccepted) {
			pendingJobs.offer(job)
			dispatcher.jobAdded(job)
		} else {
			throw new NoEligibleWorkerException
		}
	}

	def boolean canBeAccepted(TestJob job) {
		return (idleWorkers.values + busyWorkers.values) //
		.map[capabilities] //
		.exists [ providedCapabilities |
			job.capabilities.forall [ requiredCapability |
				providedCapabilities.contains(requiredCapability)
			]
		]
	}

	def TestJob getJob(String id) {
	}

	def TestExecutionKey jobOf(Worker worker) {
		return busyWorkers.get(worker.id)?.job?.copy
	}

	private def boolean isRegistered(String id) {
		return idleWorkers.containsKey(id) || busyWorkers.containsKey(id)
	}

	private def boolean isRegistered(Worker worker) {
		return worker.id.isRegistered
	}

	private def String id(Worker worker) {
		return worker.uri.toString
	}

	@FinalFieldsConstructor
	private static class Dispatcher {

		extension val TestExecutionManager

		def void workerAvailable(Worker worker) {}

		def void jobAdded(TestJob job) {
			idleWorkers.values.findFirst [ worker |
				job.capabilities.forall [ requiredCapability |
					worker.capabilities.contains(requiredCapability)
				]
			]?.assign(job)
		}

		private synchronized def void assign(Worker worker, TestJob job) {
			idleWorkers.remove(worker.id)
			busyWorkers.put(worker.id, worker)
			pendingJobs.remove(job)
			assignedJobs.offer(job)

			logger.info('''trying to assign job «job.id» to worker «worker.id»''')

			client.postAsync(worker.uri, job).whenCompleteAsync([ response, error |
				if (error !== null) {
					logger.error(error.message)
					error.printStackTrace
					assignmentFailed(worker, job)
				} else if (response.status !== Status.CREATED.statusCode) {
					logger.error(response.readEntity(String))
					assignmentFailed(worker, job)
				} else {
					worker.job = job.id
					logger.info('''assignment of job «job.id» to worker «worker.id» was successful''')
				}
			], executor)
		}

		private synchronized def void assignmentFailed(Worker worker, TestJob job) {
			logger.info('''assignment of job «job.id» to worker «worker.id» has failed''')
			assignedJobs.remove(job)
			pendingJobs.offer(job)
			busyWorkers.remove(worker.id)
			idleWorkers.put(worker.id, worker)
		}

	}

	static abstract class TestExecutionManagerException extends IllegalStateException {

		new(String message) {
			super(message)
		}

	}

	static abstract class WorkerException extends TestExecutionManagerException {

		@Accessors(PUBLIC_GETTER)
		val String workerId

		new(String workerId, String message) {
			super(message)
			this.workerId = workerId
		}

	}

	static class AlreadyRegisteredException extends WorkerException {

		new(String workerId) {
			super(workerId, 'worker already registered')
		}

	}

	static class NoSuchWorkerException extends WorkerException {

		new(String missingWorkerId) {
			super(missingWorkerId, '''no worker with id "«missingWorkerId»"''')
		}

	}

	static class NoEligibleWorkerException extends TestExecutionManagerException {

		new() {
			super('no registered worker can accept this job, or no workers registered')
		}

	}

}
