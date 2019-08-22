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
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import org.testeditor.web.backend.testexecution.worker.Worker

import static org.hamcrest.CoreMatchers.*
import static org.junit.Assert.assertThat
import static org.junit.Assert.fail
import static org.mockito.ArgumentMatchers.any
import static org.mockito.Mockito.doAnswer
import static org.mockito.Mockito.when

@RunWith(MockitoJUnitRunner)
class TestExecutionManagerTest {
	
	@Mock
	Executor testExecutor
	
	@Mock
	RestClient mockClient
	
	@InjectMocks
    TestExecutionManager managerUnderTest
    
    @Before
    def void initMocks() {
    	doAnswer[(arguments.get(0) as Runnable).run; return null].when(testExecutor).execute(any(Runnable))
    }

	@org.junit.Test
	def void canAddWorkerWithNoPendingJobs() {
		// given
		val expectedId = 'http://workers.example.com/1'
		val worker = new Worker => [
			uri = new URI(expectedId)
			capabilities = emptySet
			job = TestJob.NONE
		]
		
		// when
		val actualId = managerUnderTest.addWorker(worker)
		
		// then
		assertThat(actualId, is(expectedId))
	}
	
	@org.junit.Test
	def void cannotRemoveNonExistingWorker() {
		// given
		val id = 'invalid-worker-id'
		
		// when
		try {
			managerUnderTest.removeWorker(id)
			fail('expected exception, but none was thrown')
		}
		// then
		catch (IllegalStateException ex) {
			assertThat(ex.message, is('''no worker with id "«id»"'''))
		}
	}
	
	@org.junit.Test(expected=org.junit.Test.None)
	def void canAddAndRemoveIdleWorker() {
		// given
		val worker = new Worker => [
			uri = new URI('http://workers.example.com/1')
			capabilities = emptySet
			job = TestJob.NONE
		]
		
		// when
		val id = managerUnderTest.addWorker(worker)
		managerUnderTest.removeWorker(id)
		
		// then
		// no exception
	}
	
	@org.junit.Test
	def void canReAddWorkerAfterRemoval() {
		// given
		val worker = new Worker => [
			uri = new URI('http://workers.example.com/1')
			capabilities = emptySet
			job = TestJob.NONE
		]
		
		// when
		val id = managerUnderTest.addWorker(worker)
		managerUnderTest.removeWorker(id)
		val newId = managerUnderTest.addWorker(worker)
		
		// then
		assertThat(newId, is(id))
	}
	
	@org.junit.Test
	def void cannotAddJobWithNoWorkers() {
		// given
		val job = new TestJob => [
			id = 'the-test-job'
			status = 0
			capabilities = emptySet
		]
		
		// when
		try {
			managerUnderTest.addJob(job)
			fail('expected exception, but none was thrown')
		}
		// then
		catch (IllegalStateException ex) {
			assertThat(ex.message, is('no registered worker can accept this job, or no workers registered'))
		}
	}
	
	@org.junit.Test
	def void canAddJobWithMatchingWorker() {
		// given		
		val worker = new Worker => [
			uri = new URI('http://workers.example.com/1')
			capabilities = emptySet
			job = TestJob.NONE
		]
		managerUnderTest.addWorker(worker)
		
		val job = new TestJob => [
			id = 'the-test-job'
			status = 0
			capabilities = emptySet
		]
		
		when(mockClient.post(worker.uri, job)).thenReturn(CompletableFuture.completedFuture(Response.ok.build))
		
		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(managerUnderTest.jobOf(worker).id, is(job.id))
	}
	
	@org.junit.Test
	def void addsJobToMatchingWorker() {
		// given		
		val incapableWorker = new Worker => [
			uri = new URI('http://workers.example.com/incapable')
			capabilities = emptySet
			job = TestJob.NONE
		]
		val capableWorker = new Worker => [
			uri = new URI('http://workers.example.com/capable')
			capabilities = #{'firefox'}
			job = TestJob.NONE
		]
		
		managerUnderTest.addWorker(incapableWorker)
		managerUnderTest.addWorker(capableWorker)
		
		val job = new TestJob => [
			id = 'the-test-job'
			status = 0
			capabilities = #{'firefox'}
		]
		
		when(mockClient.post(any(URI), any(TestJob))).thenReturn(CompletableFuture.completedFuture(Response.ok.build))
		
		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(managerUnderTest.jobOf(capableWorker).id, is(job.id))
		assertThat(managerUnderTest.jobOf(incapableWorker), is(nullValue))
	}
	
	@org.junit.Test
	def void addsJobToOnlyOneMatchingWorker() {
		// given		
		val worker1 = new Worker => [
			uri = new URI('http://workers.example.com/1')
			capabilities = #{'firefox'}
			job = TestJob.NONE
		]
		val worker2 = new Worker => [
			uri = new URI('http://workers.example.com/2')
			capabilities = #{'firefox'}
			job = TestJob.NONE
		]
		
		managerUnderTest.addWorker(worker1)
		managerUnderTest.addWorker(worker2)
		
		val job = new TestJob => [
			id = 'the-test-job'
			status = 0
			capabilities = #{'firefox'}
		]
		
		when(mockClient.post(any(URI), any(TestJob))).thenReturn(CompletableFuture.completedFuture(Response.ok.build))
		
		// when
		managerUnderTest.addJob(job)

		// then
		assertThat(managerUnderTest.jobOf(worker1).id, is(job.id))
		assertThat(managerUnderTest.jobOf(worker2), is(nullValue))
	}
	
}