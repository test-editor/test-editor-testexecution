package org.testeditor.web.backend.testexecution.manager

import java.net.URI
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executor
import javax.ws.rs.core.Response
import org.junit.Before
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import org.testeditor.web.backend.testexecution.worker.Worker

import static org.assertj.core.api.Assertions.assertThat
import static org.junit.Assert.fail
import static org.mockito.ArgumentMatchers.any
import static org.mockito.Mockito.doAnswer
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.when
import javax.ws.rs.core.UriBuilder

@RunWith(MockitoJUnitRunner)
class TestExecutionManagerTest {

	@Mock
	Executor testExecutor

	@Mock
	TestStatusManager mockStatusManager

	@InjectMocks
	TestExecutionManager managerUnderTest

	@Before
	def void initMocks() {
//		doAnswer[(arguments.get(0) as Runnable).run; return null].when(testExecutor).execute(any(Runnable))
	}

	@org.junit.Test
	def void canAddWorkerWithNoPendingJobs() {
		// given
		val expectedId = 'http://workers.example.com/1'
		val worker = new Worker(new URI(expectedId), emptySet)

		// when
		val actualId = managerUnderTest.addWorker(worker)

		// then
		assertThat(actualId).isEqualTo(expectedId)
	}

	@org.junit.Test
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

	@org.junit.Test(expected=org.junit.Test.None)
	def void canAddAndRemoveIdleWorker() {
		// given
		val worker = new Worker(new URI('http://workers.example.com/1'), emptySet)

		// when
		val id = managerUnderTest.addWorker(worker)
		managerUnderTest.removeWorker(id)

	// then
	// no exception
	}

	@org.junit.Test
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

	@org.junit.Test
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

	@org.junit.Test
	def void canAddJobWithMatchingWorker() {
		// given
		val mockClient = mock(RestClient)
		val worker = new Worker(new URI('http://workers.example.com/1'), emptySet, mockClient)
		val workerJobUri = UriBuilder.fromUri(worker.uri).path('job').build
		val job = new TestJob(new TestExecutionKey('the-test-job'), emptySet, emptyList)
		when(mockClient.postAsync(workerJobUri, job)).thenReturn(CompletableFuture.completedFuture(Response.ok.build))

		managerUnderTest.addWorker(worker)

		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(managerUnderTest.jobOf(worker)).isEqualTo(job.id)
	}

	@org.junit.Test
	def void addsJobToMatchingWorker() {
		// given
		val mockClient = mock(RestClient)
		when(mockClient.postAsync(any(URI), any(TestJob))).thenReturn(CompletableFuture.completedFuture(Response.ok.build))
		val incapableWorker = new Worker(new URI('http://workers.example.com/incapable'), emptySet, mockClient)
		val capableWorker = new Worker(new URI('http://workers.example.com/capable'), #{'firefox'}, mockClient)

		managerUnderTest.addWorker(incapableWorker)
		managerUnderTest.addWorker(capableWorker)

		val job = new TestJob(new TestExecutionKey('the-test-job'), #{'firefox'}, emptyList)

		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(managerUnderTest.jobOf(capableWorker)).isEqualTo(job.id)
		assertThat(managerUnderTest.jobOf(incapableWorker)).isEqualTo(TestExecutionKey.NONE)
	}

	@org.junit.Test
	def void addsJobToOnlyOneMatchingWorker() {
		// given
		val mockClient = mock(RestClient)
		when(mockClient.postAsync(any(URI), any(TestJob))).thenReturn(CompletableFuture.completedFuture(Response.ok.build))
		val worker1 = new Worker(new URI('http://workers.example.com/1'), #{'firefox'}, mockClient)
		val worker2 = new Worker(new URI('http://workers.example.com/2'), #{'firefox'}, mockClient)

		managerUnderTest.addWorker(worker1)
		managerUnderTest.addWorker(worker2)

		val job = new TestJob(new TestExecutionKey('the-test-job'), #{'firefox'}, emptyList)

		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(#{managerUnderTest.jobOf(worker1), managerUnderTest.jobOf(worker2)}).containsExactlyInAnyOrder(job.id, TestExecutionKey.NONE)
	}

}
