package org.testeditor.web.backend.testexecution.manager

import java.util.Optional
import java.util.Set
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.ConcurrentMap
import java.util.concurrent.Executor
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.manager.TestJob.JobState
import org.testeditor.web.backend.testexecution.worker.Worker

import static org.testeditor.web.backend.testexecution.TestExecutionKey.NONE

@Singleton
class TestExecutionManager {

	static val logger = LoggerFactory.getLogger(TestExecutionManager)

	val ConcurrentMap<String, Pair<Worker, TestExecutionKey>> workers = new ConcurrentHashMap
	val ConcurrentLinkedQueue<TestExecutionKey> jobQueue = new ConcurrentLinkedQueue
	// TODO cleanup of completed jobs (e.g. removal after a fixed timeout)
	val ConcurrentMap<TestExecutionKey, TestJob> jobs = new ConcurrentHashMap

	val dispatcher = new Dispatcher(this)

	@Inject @Named('TestExecutionManagerExecutor')
	Executor executor

	@Inject
	TestStatusManager statusManager

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
		workers.put(worker.id, Pair.of(worker, NONE))
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
		if (workers.remove(id) === null) {
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
			logger.info('''accepting job «job.id»''')
			jobs.put(job.id, job)
			jobQueue.offer(job.id)
			dispatcher.jobAdded(job)
		} else {
			throw new NoEligibleWorkerException
		}
	}

	// TODO this is a work-in-progress. Right now, this is interpreted as the worker signalling the job has been completed
	def update(String workerId) {
		dispatcher.jobProgressed(workers.get(workerId))
	}

	def boolean canBeAccepted(TestJob job) {
		return workers.values.map[key.capabilities] //
		.exists [ providedCapabilities |
			job.capabilities.forall [ requiredCapability |
				providedCapabilities.contains(requiredCapability)
			]
		]
	}

	def TestJob getJob(TestExecutionKey id) {
		return jobs.getOrDefault(id, TestJob.NONE)
	}

	def Iterable<TestJob> getJobs() {
		return jobs.values
	}

	def TestExecutionKey jobOf(Worker worker) {
		return workers.getOrDefault(worker.id, Pair.of(null, NONE)).value
	}

	private def Iterable<Worker> idleWorkers() {
		return workers.values.filter[value == NONE].map[key]
	}

	private def boolean isRegistered(Worker worker) {
		return workers.containsKey(worker)
	}

	private def String id(Worker worker) {
		return worker.uri.toString
	}

	@FinalFieldsConstructor
	private static class Dispatcher {

		extension val TestExecutionManager

		def void workerAvailable(Worker worker) {}

		def void jobAdded(TestJob job) {
			idleWorkers.findFirst [ worker |
				job.capabilities.forall [ requiredCapability |
					worker.capabilities.contains(requiredCapability)
				]
			]?.assign(job)
		}

		def jobProgressed(Pair<Worker, TestExecutionKey> assignment) {
			completed(assignment.key, jobs.get(assignment.value))
		}

		private synchronized def void assign(Worker worker, TestJob job) {
			worker.assigning(job)

			worker.startJob(job).thenAcceptAsync([ success |
				if (success) {
					job.assigned
					statusManager.addTestSuiteRun(job.id, worker) [
						worker.completed(job)
					]
					logger.info('''assignment of job «job.id» to worker «worker.id» was successful''')
				} else {
					assignmentFailed(worker, job)
				}
			], executor)
		}

		private synchronized def void assigning(Worker worker, TestJob job) {
			logger.info('''trying to assign job «job.id» to worker «worker.id»''')
			jobs.replace(job.id, job.state = JobState.ASSIGNING)
			workers.replace(worker.id, Pair.of(worker, job.id))
		}

		private synchronized def void assigned(TestJob job) {
			jobs.replace(job.id, job.state = JobState.ASSIGNED)
		}

		private synchronized def void assignmentFailed(Worker worker, TestJob job) {
			logger.warn('''assignment of job «job.id» to worker «worker.id» has failed''')
			jobs.replace(job.id, job.state = JobState.PENDING)
			worker.reassignOrMarkIdle
		// TODO how to avoid loops of endlessly trying to reassign the same job to a worker that won't accept it?
		}

		private synchronized def void completed(Worker worker, TestJob job) {
			logger.info('''worker «worker.id» completed job «job.id»''')
			jobs.replace(job.id, job.state = JobState.COMPLETED)
			jobQueue.remove(job.id)
			worker.reassignOrMarkIdle
		}

		private synchronized def void reassignOrMarkIdle(Worker worker) {
			worker.capabilities.findMatchingJob.ifPresentOrElse([
				worker.assign(it)
			], [
				worker.markIdle
			])
		}

		private def void markIdle(Worker worker) {
			logger.info('''worker «worker.id» is idle''')
			workers.replace(worker.id, Pair.of(worker, NONE))
		}

		private def Optional<TestJob> findMatchingJob(Set<String> providedCapabilities) {
			return Optional.ofNullable(jobs.values.filter[state === JobState.PENDING].findFirst [
				providedCapabilities.containsAll(capabilities)
			])
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
