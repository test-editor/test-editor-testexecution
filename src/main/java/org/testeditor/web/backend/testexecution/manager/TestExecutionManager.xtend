package org.testeditor.web.backend.testexecution.manager

import java.net.URI
import java.util.HashSet
import java.util.LinkedHashSet
import java.util.Optional
import java.util.Set
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentMap
import java.util.concurrent.Executor
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.Delegate
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.manager.TestJobInfo.JobState

import static org.testeditor.web.backend.testexecution.TestExecutionKey.NONE
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.TestExecutionManagerException

@Singleton
class TestExecutionManager {

	static val logger = LoggerFactory.getLogger(TestExecutionManager)

	@Data
	static class Assignment implements OperableWorker, TestJobInfo {

		@Delegate
		val OperableWorker worker
		@Delegate
		val TestJobInfo job

	}

	// TODO cleanup of completed jobs (e.g. removal after a fixed timeout)
	val ConcurrentMap<TestExecutionKey, Assignment> assignments = new ConcurrentHashMap
	val ConcurrentMap<URI, OperableWorker> workers = new ConcurrentHashMap
	val ConcurrentMap<TestExecutionKey, TestJobInfo> jobs = new ConcurrentHashMap // val ConcurrentLinkedQueue<TestJob> jobs = new ConcurrentLinkedQueue
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
	def String addWorker(OperableWorker worker) {
		if (worker.isRegistered) {
			throw new AlreadyRegisteredException(worker.uri)
		}
		workers.put(worker.uri, worker)
		dispatcher.workerAvailable(worker)
		return worker.uri.toString
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
		val uri = new URI(id)
		if (workers.remove(uri) === null) {
			throw new NoSuchWorkerException(uri)
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
	def void addJob(TestJobInfo job) {
		if (job.canBeAccepted) {
			logger.info('''accepting job «job.id»''')
			jobs.put(job.id, job)
			dispatcher.jobAdded(job)
		} else {
			throw new NoEligibleWorkerException
		}
	}

	def void cancelJob(TestExecutionKey jobId) {
		if (jobs.containsKey(jobId)) {
			dispatcher.jobCancelled(jobId)
		} else {
			throw new NoSuchJobException(jobId)
		}

	}

	// TODO this is a work-in-progress. Right now, this is interpreted as the worker signalling the job has been completed
	def update(TestExecutionKey jobId) {
		if (jobs.containsKey(jobId)) {
			dispatcher.jobProgressed(jobId)
		} else {
			throw new NoSuchJobException(jobId)
		}

	}

	def boolean canBeAccepted(TestJobInfo job) {
		return workers.values.exists[providedCapabilities.containsAll(job.requiredCapabilities)]
	}

	def Iterable<WorkerInfo> getWorkers() {
		return new HashSet<WorkerInfo>(workers.values)
	}

	def Iterable<TestJobInfo> getJobs() {
		return new LinkedHashSet<TestJobInfo>(jobs.values)
	}

	def TestExecutionKey jobOf(WorkerInfo worker) {
		return assignments.values.findFirst[uri == worker.uri]?.id ?: NONE
	}

	// TODO this is expensive!!!
	private def Iterable<OperableWorker> idleWorkers() {
		return workers.values.filter[checkStatus !== TestStatus.RUNNING]
	}

	private def boolean isRegistered(OperableWorker worker) {
		return workers.containsKey(worker.uri)
	}

	@FinalFieldsConstructor
	private static class Dispatcher {

		extension val TestExecutionManager

		def void workerAvailable(OperableWorker worker) {
			jobs.values.filter[state === JobState.PENDING].findFirst [
				worker.providedCapabilities.containsAll(requiredCapabilities)
			]?.assignTo(worker)
		}

		def void jobAdded(TestJobInfo job) {
			idleWorkers.findFirst[providedCapabilities.containsAll(job.requiredCapabilities)]?.assign(job)
		}

		def void jobProgressed(TestExecutionKey jobId) {
			jobs.get(jobId) => [
				switch (state) {
					case PENDING:
						throw new IllegalStateException('''job "«jobId»" is still pending''')
					case ASSIGNING,
					case ASSIGNED: {
						assignments.get(jobId).completed
					}
					case COMPLETED:
						throw new AlreadyCompletedException(jobId)
				}
			]

		}

		def synchronized void jobCancelled(TestExecutionKey jobId) {
			jobs.get(jobId) => [
				switch (state) {
					case PENDING:
						jobs.remove(jobId)
					case ASSIGNING,
					case ASSIGNED: {
						assignments.get(jobId).kill
						assignments.remove(jobId)
						jobs.remove(jobId)
					}
					case COMPLETED:
						throw new AlreadyCompletedException(jobId)
				}
			]

		}

		private synchronized def void assignTo(TestJobInfo job, OperableWorker worker) {
			worker.assign(job)
		}

		private synchronized def void assign(OperableWorker worker, TestJobInfo job) {
			val assignment = worker.assigning(job)

			worker.startJob(job).thenAcceptAsync([ success |
				if (success) {
					job.assigned
					statusManager.addTestSuiteRun(job.id, worker) [
						assignment.completed
					]
					logger.info('''assignment of job «job.id» to worker «worker.uri» was successful''')
				} else {
					assignment.failed
				}
			], executor)
		}

		private synchronized def Assignment assigning(OperableWorker worker, TestJobInfo pendingJob) {
			logger.info('''trying to assign job «pendingJob.id» to worker «worker.uri»''')
			val job = (pendingJob.state = JobState.ASSIGNING) => [ job |
				jobs.replace(job.id, job)
				assignments.put(job.id, new Assignment(worker, job))
			]
			return assignments.get(job.id)
		}

		private synchronized def void assigned(TestJobInfo job) {
			jobs.replace(job.id, job.state = JobState.ASSIGNED)
		}

		private synchronized def void failed(Assignment it) {
			logger.warn('''assignment of job «job.id» to worker «worker.uri» has failed''')
			jobs.replace(job.id, job.state = JobState.PENDING)

			// TODO how to avoid loops of endlessly trying to reassign the same job to a worker that won't accept it (but isn't reporting to be busy, either)?

			if (worker.checkStatus === TestStatus.IDLE) {
				reassignOrMarkIdle
			} else {
				logger.info('''worker «worker.uri» is busy''')
			}
		}

		private synchronized def void completed(Assignment it) {
			logger.info('''worker «worker.uri» completed job «job.id»''')
			jobs.replace(job.id, job.state = JobState.COMPLETED)
			reassignOrMarkIdle
		}

		private synchronized def void reassignOrMarkIdle(Assignment it) {
			logger.info('''worker «worker.uri» is idle''')
			assignments.remove(job.id)
			worker.getProvidedCapabilities.findMatchingJob.ifPresent[job|worker.assign(job)]
		}

		private def Optional<TestJobInfo> findMatchingJob(Set<String> providedCapabilities) {
			return Optional.ofNullable(jobs.values.filter[state === JobState.PENDING].findFirst [
				providedCapabilities.containsAll(requiredCapabilities)
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

		new(URI workerUri) {
			super(workerUri.toString, 'worker already registered')
		}

	}

	static class NoSuchWorkerException extends WorkerException {

		new(URI missingWorkerUri) {
			super(missingWorkerUri.toString, '''no worker with id "«missingWorkerUri»"''')
		}

	}

	static class NoSuchJobException extends TestExecutionManagerException {

		new(TestExecutionKey missingJobId) {
			super('''no job with id "«missingJobId.toString»"''')
		}

	}

	static class NoEligibleWorkerException extends TestExecutionManagerException {

		new() {
			super('no registered worker can accept this job, or no workers registered')
		}

	}

	static class AlreadyCompletedException extends TestExecutionManagerException {

		new(TestExecutionKey jobId) {
			super('''job "«jobId»" has already been completed''')
		}

	}

}
