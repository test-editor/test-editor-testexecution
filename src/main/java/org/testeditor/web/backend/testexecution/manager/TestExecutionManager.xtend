package org.testeditor.web.backend.testexecution.manager

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentMap
import java.util.concurrent.ConcurrentNavigableMap
import java.util.concurrent.ConcurrentSkipListMap
import org.testeditor.web.backend.testexecution.worker.Worker

class TestExecutionManager {
	val ConcurrentMap<String, Worker> idleWorkers = new ConcurrentHashMap
	val ConcurrentMap<String, Worker> busyWorkers = new ConcurrentHashMap
	val ConcurrentNavigableMap<String, TestJob> pendingJobs = new ConcurrentSkipListMap
	val ConcurrentNavigableMap<String, TestJob> assignedJobs = new ConcurrentSkipListMap
	
	
	/**
	 * Adds a new worker.
	 * 
	 * If there are pending jobs, the test execution manager will immediately try to assign one to the new worker:
	 * All pending jobs are filtered for the ones that can run on the newly added worker, according to their capabilities.
	 * From this subset of jobs, the one that was enqueued first will be assigned to the worker.
	 */
	def void addWorker(Worker worker) {
		
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
		
	}
	
	def TestJob getJob(String id) {
		
	}
	
	private static class Dispatcher {
		def void workerAvailable(Worker worker) {}
		def void jobAdded(TestJob job) {}
	}
}