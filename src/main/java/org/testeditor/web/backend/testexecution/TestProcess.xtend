package org.testeditor.web.backend.testexecution

import java.util.LinkedList
import java.util.List
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.stream.Collectors
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.common.RunningTest
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.webapi.TestSuiteResource

import static org.testeditor.web.backend.testexecution.common.TestStatus.*

/**
 * Keeps track of the status of a single test execution.
 * 
 * This class should be thread-safe, since
 * a) its {@link #process process} field is only ever accessed for reading, 
 *    except when it is set to null by {@link #markCompleted(int) markCompleted),
 *    which is why all methods first copy the reference into a local variable
 *    and then perform a null check to be on the safe side; and
 * b) its {@link #status status} field may be written to by multiple threads
 *    multiple times, but not with different values, because all threads
 *    implicitly synchronize over whether the external process is alive: once
 *    it terminated, the only value that can be written as status is its
 *    exit value, which is fixed at that point. 
 */
class TestProcess implements RunningTest {

	static val logger = LoggerFactory.getLogger(TestProcess)

	public static val TestProcess DEFAULT_IDLE_TEST_PROCESS = new TestProcess()
	public static val int DEFAULT_WAIT_TIMEOUT_SECONDS = 5

	val descendantsBeforeKill = <ProcessHandle>newLinkedList
	var Process process
	var TestStatus status
	val int timeout
	val (TestStatus)=>void onCompleted

	new(Process process) {
		this(process, DEFAULT_WAIT_TIMEOUT_SECONDS)[]
	}

	new(Process process, (TestStatus)=>void onCompleted) {
		this(process, DEFAULT_WAIT_TIMEOUT_SECONDS, onCompleted)
	}

	new(Process process, int timeoutSeconds, (TestStatus)=>void onCompleted) {
		if (process === null) {
			throw new NullPointerException("Process must initially not be null")
		}
		this.process = process
		this.status = RUNNING
		this.onCompleted = onCompleted
		this.timeout = timeoutSeconds
	}

	private new() {
		this.process = null
		this.status = IDLE
		this.timeout = DEFAULT_WAIT_TIMEOUT_SECONDS
		this.onCompleted = []
	}

	/**
	 * Checks the current execution status of this test process and returns it
	 * immediately.
	 * This method checks if the corresponding operating system process and its
	 * subprocesses have all terminated, and if so, updates the status
	 * accordingly, before returning it.
	 */
	override TestStatus checkStatus() {
		updateStatusIfAllProcessesTerminated
		return status
	}
	
	/**
	 * If this test process is still running, waits for its termination no
	 * longer than {@link #WAIT_TIMEOUT_SECONDS}. Returns {@link #checkStatus()}
	 * as soon as the test process terminates, or after the timeout.
	 */
	override TestStatus waitForStatus() {
		if (process !== null && testIsAlive) {
			waitForAll(timeout, TimeUnit.SECONDS)
		}
		return this.checkStatus
	}

	/** Terminates this test process.
	 * Sends kill signals to all operating system processes belonging to this
	 * test process, waiting for each to either terminate on its own, or killing
	 * them forcefully after a timeout.
	 * 
	 * Note: this is obviously not an atomic operation. In particular, the
	 * {@link #process parent process} may already be dead, and show as having
	 * no descendants, even though some sub-processes that were sent into the
	 * background are still running.
	 */
	override void kill() {
		val processRef = this.process
		if (processRef !== null) {
			val descendants = synchronized (descendantsBeforeKill) {
					if (descendantsBeforeKill.empty) {
						descendantsBeforeKill.addAll(processRef.descendants.collect(Collectors.toList))
					}
					new LinkedList => [addAll(descendantsBeforeKill)]
				}
			descendants.kill
			processRef.toHandle.kill
			updateStatusIfAllProcessesTerminated
		}
	}

	private def synchronized void updateStatusIfAllProcessesTerminated() {
		if (!testIsAlive) {
			if (process !== null) {
				status = process.exitValue.toTestStatus
				process = null
				onCompleted?.apply(status)
			}
		}
	}

	// get all descendants and wait for them to terminate (onExit.get(...))
	// or timeout. Returns true if all descendants terminate, and false as soon
	// as a timeout occurs. In the worst case, this method waits the specified
	// timeout times the number of descendant processes.
	private def boolean waitForAll(long timeout, TimeUnit unit) {
		return allProcesses[map[onExit]].dropWhile [
			try {
				get(timeout, unit)
				true
			} catch (TimeoutException ex) {
				false
			}
		].empty
	}

	private def void kill(ProcessHandle handle) {
		handle => [
			destroy
			try {
				killForciblyIfNotDeadAfterTimeout
			} catch (InterruptedException ex) {
				Thread.currentThread.interrupt
				killForciblyIfNotDeadAfterTimeout
			}
		]
	}

	private def void kill(List<ProcessHandle> handles) {
		handles.filter[alive].forEach [
			logger.info('''killing lingering child process with PID «pid»''')
			kill(it)
		]
	}

	private def void killForciblyIfNotDeadAfterTimeout(ProcessHandle handle) {
		try {
			handle.onExit.get(timeout, TimeUnit.SECONDS)
		} catch (TimeoutException timeout) {
			logger.info('''timeout reached while waiting for process with PID «handle.pid» to die. Killing forcibly...''')
			handle.killForcibly
		}
	}

	private def void killForcibly(ProcessHandle handle) {
		handle.destroyForcibly
		try {
			handle.onExit.get(1, TimeUnit.SECONDS)
		} catch (TimeoutException timeout) {
			logger.error('''failed to terminate test execution (process id: «handle.pid»)''')
			throw new UnresponsiveTestProcessException
		}
	}

	private def boolean testIsAlive() {
		return allProcesses[exists[alive]]
	}

	private def <T> T allProcesses((Iterable<ProcessHandle>)=>T action) {
		return actOnProcesses(true, action)
	}

	// gets a list of all descendant processes, and optionally the parent process,
	// and performs the provided action on it.
	// Any action that requires access to the descendant processes must go through
	// this method.
	//
	// It synchronizes on descendantsBeforeKill, retrieving that list if it is
	// not empty, i.e. a kill request has been received. As soon as killing the
	// operating system processes corresponding to this test process has commenced,
	// retrieving the descendant processes from the parent is not reliable anymore.
	private def <T> T actOnProcesses(boolean withParent, (Iterable<ProcessHandle>)=>T action) {
		val processRef = this.process

		return synchronized (descendantsBeforeKill) {
			val descendants = if (descendantsBeforeKill.empty) {
					processRef?.descendants?.collect(Collectors.toList) ?: #[]
				} else {
					descendantsBeforeKill
				}

			val processes = if (withParent && processRef !== null) {
					descendants + #[processRef.toHandle]
				} else {
					descendants
				}

			action.apply(processes)
		}
	}

	private def TestStatus toTestStatus(int exitCode) {
		if (exitCode == 0) {
			return SUCCESS
		} else {
			return FAILED
		}
	}
}

class UnresponsiveTestProcessException extends RuntimeException {

	new() {
		super('A test process has become unresponsive and could not be terminated')
	}

}
