package org.testeditor.web.backend.testexecution.manager

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentMap
import java.util.concurrent.ConcurrentNavigableMap
import java.util.concurrent.ConcurrentSkipListMap
import java.util.concurrent.Executor
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import org.testeditor.web.backend.testexecution.worker.Worker

@Singleton
class TestExecutionManager {

	val ConcurrentMap<String, Worker> idleWorkers = new ConcurrentHashMap
	val ConcurrentMap<String, Worker> busyWorkers = new ConcurrentHashMap
	val ConcurrentNavigableMap<String, TestJob> pendingJobs = new ConcurrentSkipListMap
	val ConcurrentNavigableMap<String, TestJob> assignedJobs = new ConcurrentSkipListMap
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
			throw new IllegalStateException('worker already registered')
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
			throw new IllegalStateException('''no worker with id "«id»"''')
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
			pendingJobs.put(job.id, job)
			dispatcher.jobAdded(job)
		} else {
			throw new IllegalStateException('no registered worker can accept this job, or no workers registered')
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
	
	def TestJob jobOf(Worker worker) {
		return busyWorkers.get(worker.id)?.job?.copy
	}

	private def boolean isRegistered(String id) {
		return idleWorkers.containsKey(id) || busyWorkers.containsKey(id)
	}

	private def boolean isRegistered(Worker worker) {
		return worker.id.isRegistered
	}

	private def String id(Worker worker) {
		return worker.url.toString
	}

	@FinalFieldsConstructor
	private static class Dispatcher {
		extension val TestExecutionManager
		
		def void workerAvailable(Worker worker) {}

		def void jobAdded(TestJob job) {
			idleWorkers.values
				.findFirst[ worker |
					job.capabilities.forall [ requiredCapability |
						worker.capabilities.contains(requiredCapability)
					]
				]?.assign(job)
		}
		
		private synchronized def void assign(Worker worker, TestJob job) {
			idleWorkers.remove(worker.id)
			busyWorkers.put(worker.id, worker)
			pendingJobs.remove(job.id)
			assignedJobs.put(job.id, job)
			
			client.post(worker.url, job).whenCompleteAsync([response, error |
				if (error !== null) {
					assignmentFailed(worker, job)
				} else {
					worker.job = job
				}
			], executor)
		}
		
		private synchronized def void assignmentFailed(Worker worker, TestJob job) {
			assignedJobs.remove(job.id)
			pendingJobs.put(job.id, job)
			busyWorkers.remove(worker.id)
			idleWorkers.put(worker.id, worker)
		}

	}

}
