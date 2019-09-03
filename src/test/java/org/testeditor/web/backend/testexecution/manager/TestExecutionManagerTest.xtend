package org.testeditor.web.backend.testexecution.manager

import java.net.URI
import java.util.concurrent.Executor
import org.assertj.core.api.SoftAssertions
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.WorkerMocking
import org.testeditor.web.backend.testexecution.WorkerMocking.WorkerStub
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.AlreadyRegisteredException
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.NoSuchJobException
import org.testeditor.web.backend.testexecution.worker.Worker

import static org.assertj.core.api.Assertions.assertThat
import static org.junit.Assert.fail
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.doAnswer
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.spy
import static org.mockito.Mockito.verify
import static org.mockito.Mockito.inOrder
import static org.testeditor.web.backend.testexecution.manager.TestJobInfo.JobState.*

@RunWith(MockitoJUnitRunner)
class TestExecutionManagerTest {

	extension val WorkerMocking = new WorkerMocking

	@Mock
	Executor testExecutor

	@Mock
	TestStatusManager mockStatusManager

	@InjectMocks
	TestExecutionManager managerUnderTest

	@Before
	def void initMocks() {
		doAnswer[(arguments.get(0) as Runnable).run; return null].when(testExecutor).execute(any(Runnable))
	}

	@Test
	def void canAddWorkerWithNoPendingJobs() {
		// given
		val expectedId = 'http://workers.example.com/1'
		val worker = new Worker(new URI(expectedId), emptySet)

		// when
		val actualId = managerUnderTest.addWorker(worker)

		// then
		assertThat(actualId).isEqualTo(expectedId)
	}

	@Test
	def void cannotRemoveNonExistingWorker() {
		// given
		val id = 'invalid-worker-id'

		// when
		try {
			managerUnderTest.removeWorker(id)
			fail('expected exception, but none was thrown')
		} // then
		catch (IllegalStateException ex) {
			assertThat(ex.message).isEqualTo('''no worker with id "«id»"'''.toString)
		}
	}

	@Test(expected=Test.None)
	def void canAddAndRemoveIdleWorker() {
		// given
		val worker = new Worker(new URI('http://workers.example.com/1'), emptySet)

		// when
		val id = managerUnderTest.addWorker(worker)
		managerUnderTest.removeWorker(id)

	// then
	// no exception
	}

	@Test
	def void canReAddWorkerAfterRemoval() {
		// given
		val worker = new Worker(new URI('http://workers.example.com/1'), emptySet)

		// when
		val id = managerUnderTest.addWorker(worker)
		managerUnderTest.removeWorker(id)
		val newId = managerUnderTest.addWorker(worker)

		// then
		assertThat(newId).isEqualTo(id)
	}

	@Test
	def void cannotAddMoreThanOneWorkerWithTheSameUri() {
		// given
		val worker = mock(Worker).withUri('http://workers.example.com/1')
		val workerWithSameUri = mock(Worker).withUri('http://workers.example.com/1')

		managerUnderTest.addWorker(worker)

		// when
		try {
			managerUnderTest.addWorker(workerWithSameUri)
			fail('expected exception, but none was thrown')
		} // then
		catch (AlreadyRegisteredException ex) {
			assertThat(ex.message).isEqualTo('worker already registered')
		}
	}

	@Test
	def void cannotAddJobWithNoWorkers() {
		// given
		val job = new TestJob(new TestExecutionKey('the-test-job'), emptySet, emptyList)

		// when
		try {
			managerUnderTest.addJob(job)
			fail('expected exception, but none was thrown')
		} // then
		catch (IllegalStateException ex) {
			assertThat(ex.message).isEqualTo('no registered worker can accept this job, or no workers registered')
		}
	}

	@Test
	def void canAddJobWithMatchingWorker() {
		// given
		val worker = mock(Worker).withUri('http://workers.example.com/1').thatIsIdle.thatCanBeStarted
		val job = new TestJob(new TestExecutionKey('the-test-job'), emptySet, emptyList)

		managerUnderTest.addWorker(worker)

		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(managerUnderTest.jobOf(worker)).isEqualTo(job.id)
		assertThat(managerUnderTest.jobs).containsExactly(job)
		verify(worker).startJob(job)
	}

	@Test
	def void addsJobToMatchingWorker() {
		// given
		val capableWorker = mock(Worker).withCapabilities('firefox').withUri('http://workers.example.com/capable').thatIsIdle.thatCanBeStarted
		val incapableWorker = mock(Worker).withCapabilities.withUri('http://workers.example.com/incapable').thatIsIdle.thatCanBeStarted

		managerUnderTest.addWorker(incapableWorker)
		managerUnderTest.addWorker(capableWorker)

		val job = new TestJob(new TestExecutionKey('the-test-job'), #{'firefox'}, emptyList)

		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(managerUnderTest.jobOf(capableWorker)).isEqualTo(job.id)
		assertThat(managerUnderTest.jobOf(incapableWorker)).isEqualTo(TestExecutionKey.NONE)
	}

	@Test
	def void addsJobToOnlyOneMatchingWorker() {
		// given
		val worker1 = mock(Worker).withCapabilities('firefox').withUri('http://workers.example.com/1').thatIsIdle.thatCanBeStarted
		val worker2 = mock(Worker).withCapabilities('firefox').withUri('http://workers.example.com/2').thatIsIdle.thatCanBeStarted

		managerUnderTest.addWorker(worker1)
		managerUnderTest.addWorker(worker2)

		val job = new TestJob(new TestExecutionKey('the-test-job'), #{'firefox'}, emptyList)

		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(#{managerUnderTest.jobOf(worker1), managerUnderTest.jobOf(worker2)}).containsExactlyInAnyOrder(job.id, TestExecutionKey.NONE)
	}

	@Test
	def void canCancelJob() {
		// given
		val worker = mock(Worker).withCapabilities('firefox').withUri('http://workers.example.com/capable').thatIsIdle.thatCanBeStarted
		val job = new TestJob(new TestExecutionKey('the-test-job'), emptySet, emptyList)

		managerUnderTest.addWorker(worker)
		managerUnderTest.addJob(job)

		// when
		managerUnderTest.cancelJob(job.id)

		// then
		assertThat(managerUnderTest.jobOf(worker)).isEqualTo(TestExecutionKey.NONE)
	}

	@Test
	def void cannotCancelNonExistingJob() {
		// given
		val job = new TestJob(new TestExecutionKey('the-test-job'), emptySet, emptyList)

		// when
		try {
			managerUnderTest.cancelJob(job.id)
			fail('expected exception, but none was thrown')
		} // then
		catch (IllegalStateException ex) {
			assertThat(ex.message).isEqualTo('no job with id "the-test-job---"')
		}
	}

	@Test
	def void cancellingJobNotifiesAssignedWorker() {
		// given
		val worker = mock(Worker).withUri('http://workers.example.com/1').thatIsIdle.thatCanBeStarted
		val job = new TestJob(new TestExecutionKey('the-test-job'), emptySet, emptyList)

		managerUnderTest.addWorker(worker)
		managerUnderTest.addJob(job)

		// when
		managerUnderTest.cancelJob(job.id)

		// then
		verify(worker).kill
	}

	@Test
	def void updateCompletesJobAndFreesWorker() {
		// given
		val worker = new WorkerStub => [
			uri = new URI('http://workers.example.com/stub')
			providedCapabilities = emptySet
			status = TestStatus.IDLE
		]
		val job = new TestJob(new TestExecutionKey('the-test-job'), emptySet, emptyList)

		managerUnderTest.addWorker(worker)
		managerUnderTest.addJob(job)
		worker.status = TestStatus.SUCCESS

		// when
		managerUnderTest.update(job.id)

		// then
		assertThat(managerUnderTest.jobOf(worker)).isEqualTo(TestExecutionKey.NONE)
		assertThat(managerUnderTest.jobs.map[state]).containsOnly(COMPLETED)
	}

	@Test
	def void nextJobIsStartedAfterFirstOneHasBeenCompleted() {
		// given
		val worker = new WorkerStub => [
			uri = new URI('http://workers.example.com/stub')
			providedCapabilities = emptySet
			status = TestStatus.IDLE
		]
		val job = new TestJob(new TestExecutionKey('the-first-test-job'), emptySet, emptyList)
		val nextJob = new TestJob(new TestExecutionKey('the-second-test-job'), emptySet, emptyList)

		managerUnderTest.addWorker(worker)
		managerUnderTest.addJob(job)
		worker.status = TestStatus.SUCCESS
		managerUnderTest.update(job.id)

		// when
		managerUnderTest.addJob(nextJob)

		// then
		assertThat(managerUnderTest.jobs.map[state]).containsExactly(COMPLETED, ASSIGNED)
		assertThat(managerUnderTest.jobOf(worker)).isEqualTo(nextJob.id)
	}

	@Test
	def void updateOfUnknownJobIdRaisesAnException() {
		// given
		val worker = new WorkerStub => [
			uri = new URI('http://workers.example.com/stub')
			providedCapabilities = emptySet
			status = TestStatus.IDLE
		]
		val job = new TestJob(new TestExecutionKey('the-test-job'), emptySet, emptyList)

		managerUnderTest.addWorker(worker)
		managerUnderTest.addJob(job)
		worker.status = TestStatus.SUCCESS

		// when
		try {
			managerUnderTest.update(new TestExecutionKey('unknown-id'))
			fail('expected exception, but none was thrown')

		// then
		} catch (NoSuchJobException ex) {
			new SoftAssertions => [
				assertThat(ex.message).isEqualTo('no job with id "unknown-id---"')
				assertThat(managerUnderTest.jobs.map[id]).containsExactly(job.id)
				assertThat(managerUnderTest.jobs.map[state]).containsExactly(ASSIGNED)
				assertThat(managerUnderTest.jobOf(worker).toString).isEqualTo(job.id.toString)
				assertAll
			]

		}
	}

	@Test
	def void jobsAreProperlyEnqueued() {
		// given
		val worker = new WorkerStub => [
			uri = new URI('http://workers.example.com/stub')
			providedCapabilities = emptySet
			status = TestStatus.IDLE
		]
		managerUnderTest.addWorker(worker)

		val jobs = #[
			new TestJob(new TestExecutionKey('the-first-test-job'), emptySet, emptyList),
			new TestJob(new TestExecutionKey('the-second-test-job'), emptySet, emptyList),
			new TestJob(new TestExecutionKey('the-third-test-job'), emptySet, emptyList)
		]

		// when
		jobs.forEach[managerUnderTest.addJob(it)]

		// then
		new SoftAssertions => [
			assertThat(managerUnderTest.jobs.map[state]).containsExactly(ASSIGNED, PENDING, PENDING)
			assertThat(managerUnderTest.jobOf(worker).toString).isEqualTo(jobs.head.id.toString)
			assertAll
		]
	}

	@Test
	def void jobsAreHandledInTheGivenOrder() {
		// given
		val worker = spy(new WorkerStub => [
			uri = new URI('http://workers.example.com/stub')
			providedCapabilities = emptySet
			status = TestStatus.IDLE
		])
		managerUnderTest.addWorker(worker)

		val jobs = #[
			new TestJob(new TestExecutionKey('the-first-test-job'), emptySet, emptyList),
			new TestJob(new TestExecutionKey('the-second-test-job'), emptySet, emptyList),
			new TestJob(new TestExecutionKey('the-third-test-job'), emptySet, emptyList)
		]

		jobs.forEach[managerUnderTest.addJob(it)]

		// when
		jobs.forEach [
			worker.status = TestStatus.SUCCESS
			managerUnderTest.update(id)
		]

		// then
		assertThat(managerUnderTest.jobs.map[state]).allMatch[it === COMPLETED]
		inOrder(worker) => [
			jobs.forEach[job|verify(worker).startJob(job)]
		]
	}

	@Test
	def void allJobsAreAssignedToIdleWorkers() {
		// given
		val workers = #[1, 2, 3].map [ index |
			new WorkerStub => [
				uri = new URI('http://workers.example.com/stub' + index)
				providedCapabilities = emptySet
				status = TestStatus.IDLE
			]
		]
		workers.forEach [
			managerUnderTest.addWorker(it)
			assertThat(managerUnderTest.jobOf(it)).isEqualTo(TestExecutionKey.NONE)
		]

		val jobs = #[
			new TestJob(new TestExecutionKey('the-first-test-job'), emptySet, emptyList),
			new TestJob(new TestExecutionKey('the-second-test-job'), emptySet, emptyList),
			new TestJob(new TestExecutionKey('the-third-test-job'), emptySet, emptyList)
		]

		// when
		jobs.forEach[managerUnderTest.addJob(it)]

		// then
		new SoftAssertions => [
			assertThat(managerUnderTest.jobs.size).isEqualTo(3)
			assertThat(managerUnderTest.jobs.map[state]).allMatch[it === ASSIGNED]
			workers.forEach [ worker |
				assertThat(managerUnderTest.jobOf(worker).toString).isNotEqualTo(TestExecutionKey.NONE.toString)
			]
			assertAll
		]

	}

	@Test
	def void assignsJobsWhenWorkerIsAdded() {
		// given
		val firstWorker = new WorkerStub => [
			uri = new URI('http://workers.example.com/firstStub')
			providedCapabilities = emptySet
			status = TestStatus.IDLE
		]
		managerUnderTest.addWorker(firstWorker)

		val jobs = #[
			new TestJob(new TestExecutionKey('the-first-test-job'), emptySet, emptyList),
			new TestJob(new TestExecutionKey('the-second-test-job'), emptySet, emptyList)
		]
		jobs.forEach[managerUnderTest.addJob(it)]
		assertThat(managerUnderTest.jobs.map[state]).containsExactly(ASSIGNED, PENDING)

		val secondWorker = new WorkerStub => [
			uri = new URI('http://workers.example.com/secondStub')
			providedCapabilities = emptySet
			status = TestStatus.IDLE
		]

		// when
		managerUnderTest.addWorker(secondWorker)

		// then
		assertThat(managerUnderTest.jobs.map[state]).containsExactly(ASSIGNED, ASSIGNED)


	}

}
