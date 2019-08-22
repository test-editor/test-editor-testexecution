package org.testeditor.web.backend.testexecution.manager

import java.net.URI
import javax.ws.rs.core.Response
import org.testeditor.web.backend.testexecution.worker.Worker

import static org.hamcrest.CoreMatchers.*
import static org.junit.Assert.assertThat
import static org.mockito.Mockito.mock

abstract class WorkersAPITest extends AbstractResourceTest<WorkersAPI> {
	
	TestExecutionManager manager
	
	protected def TestExecutionManager getManager() {
		if (manager === null) {
			manager = mock(TestExecutionManager)
		}
		return manager
	}
		
	@org.junit.Test
	def void workersCanRegisterThemselves() {
		// given
		val worker = new Worker => [ 
			uri = new URI('http://worker.example.org')
			capabilities = emptySet
			job = TestJob.NONE
		]
		
		// when
		val response = systemUnderTest.registerWorker(worker)
		
		// then
		assertThat(response.status, is(201))
		assertThat(response.stringHeaders.getFirst('Location'), is(baseUrl + 'http%3A%2F%2Fworker.example.org'))
	}
	
	@org.junit.Test
	def void onlyOneWorkerPerUrlIsAllowed() {
		// given
		val firstWorker = new Worker => [ 
			uri = new URI('http://worker.example.org')
			capabilities = emptySet
			job = TestJob.NONE
		]
		val secondWorker = new Worker => [ 
			uri = new URI('http://worker.example.org')
			capabilities = #{'linux', 'chrome76'}
			job = TestJob.NONE
		]
		
		// when
		val firstResponse = systemUnderTest.registerWorker(firstWorker)
		val secondResponse = systemUnderTest.registerWorker(secondWorker)
		
		// then
		assertThat(firstResponse.status, is(201))
		assertThat(secondResponse.status, is(409))
		assertThat(secondResponse.getBody(String), is('There is already a worker registered for this URL.'))
		assertThat(secondResponse.headers.get('Location'), is(firstResponse.headers.get('Location')))
	}
	
	@org.junit.Test
	def void registeredWorkersCanBeUnregistered() {
		// given
		val worker = new Worker => [ 
			uri = new URI('http://worker.example.org')
			capabilities = emptySet
			job = TestJob.NONE
		]
		val registered = systemUnderTest.registerWorker(worker)
		val unregisterUrl = registered.stringHeaders.getFirst('Location') as String
		val workerId = unregisterUrl.substring(baseUrl.length)
		
		// when
		val response = systemUnderTest.unregisterWorker(workerId)
		
		
		// then
		assertThat(response.status, is(200))
	}
	
	@org.junit.Test
	def void nonExistantWorkersCannotBeUnregistered() {
		// given
		val workerId = 'non-existing-worker-id'
		
		// when
		val response = systemUnderTest.unregisterWorker(workerId)
		
		
		// then
		assertThat(response.status, is(404))
		assertThat(response.getBody(String), is('Worker does not exist. It may have already been deleted.'))
	}
	
	@org.junit.Test
	def void workersCannotBeDeletedTwice() {// Note: DELETE should be idempotent, and it is (deleting multiple times does not change the server state).
		// given							//       The response is _not_ considered for idempotency, see 
		val worker = new Worker => [		//       https://stackoverflow.com/questions/24713945/does-idempotency-include-response-codes/24713946#24713946
			uri = new URI('http://worker.example.org')
			capabilities = emptySet
			job = TestJob.NONE
		]
		val registered = systemUnderTest.registerWorker(worker)
		val unregisterUrl = registered.stringHeaders.getFirst('Location') as String
		val workerId = unregisterUrl.substring(baseUrl.length)
		
		// when
		val firstResponse = systemUnderTest.unregisterWorker(workerId)
		val secondResponse = systemUnderTest.unregisterWorker(workerId)
		
		
		// then
		assertThat(firstResponse.status, is(200))
		assertThat(secondResponse.status, is(404))
		assertThat(secondResponse.getBody(String), is('Worker does not exist. It may have already been deleted.'))
	}
	
	
	
	private def <T> T getBody(Response response, Class<T> type) {
		return try {
			response.readEntity(type)
		} catch (IllegalStateException ex) {
			response.entity as T
		}
	}
}
