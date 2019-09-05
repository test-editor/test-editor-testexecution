package org.testeditor.web.backend.testexecution.manager

import java.net.URI
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriBuilder
import org.junit.Before
import org.junit.Test
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.MockitoAnnotations
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.AlreadyRegisteredException
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.NoSuchWorkerException

import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.doNothing
import static org.mockito.Mockito.doThrow
import static org.mockito.Mockito.when

abstract class WorkersAPITest extends AbstractResourceTest<WorkersAPI> {

	@Mock
	protected TestExecutionManager manager
	@Mock
	protected UriAppender appender

	@InjectMocks
	protected WorkersResource _workersResource

	protected def WorkersResource getWorkersResource() {
		initMocks
		return _workersResource
	}
	
	def void initMocks() {
		if (_workersResource === null) {
			MockitoAnnotations.initMocks(this)
		}		
	}

	@Before
	def void setupUriAppender() {
		initMocks
		when(appender.append(any, anyString)).then [
			UriBuilder.fromUri(baseUrl).path(arguments.get(1) as String).build
		]
	}

	@Test
	def void workersCanRegisterThemselves() {
		// given
		val worker = new WorkerClient(new URI('http://worker.example.org'), emptySet)
		when(manager.addWorker(any(WorkerClient))).thenReturn('http://worker.example.org')

		// when
		val response = systemUnderTest.registerWorker(worker)

		// then
		assertThat(response.status).isEqualTo(201)
		assertThat(response.stringHeaders.getFirst('Location')).isEqualTo(baseUrl + 'http%3A%2F%2Fworker.example.org')
	}

	@Test
	def void onlyOneWorkerPerUrlIsAllowed() {
		// given
		val workerUri = new URI('http://worker.example.org')
		val firstWorker = new WorkerClient(workerUri, emptySet)
		val secondWorker = new WorkerClient(workerUri, #{'linux', 'chrome76'})
		when(manager.addWorker(any(WorkerClient))).thenReturn('http://worker.example.org').thenThrow(
			new AlreadyRegisteredException(workerUri))

		// when
		val firstResponse = systemUnderTest.registerWorker(firstWorker)
		val secondResponse = systemUnderTest.registerWorker(secondWorker)

		// then
		assertThat(firstResponse.status).isEqualTo(201)
		assertThat(secondResponse.status).isEqualTo(409)
		assertThat(secondResponse.getBody(String)).isEqualTo('There is already a worker registered for this URL.')
		assertThat(secondResponse.headers.get('Location')).isEqualTo(firstResponse.headers.get('Location'))
	}

	@Test
	def void registeredWorkersCanBeUnregistered() {
		// given
		val worker = new WorkerClient(new URI('http://worker.example.org'), emptySet)
		when(manager.addWorker(any(WorkerClient))).thenReturn('http://worker.example.org')
		val registered = systemUnderTest.registerWorker(worker)
		val unregisterUrl = registered.stringHeaders.getFirst('Location') as String
		val workerId = unregisterUrl.substring(baseUrl.length)

		// when
		val response = systemUnderTest.unregisterWorker(workerId)

		// then
		assertThat(response.status).isEqualTo(200)
	}

	@Test
	def void nonExistantWorkersCannotBeUnregistered() {
		// given
		val workerId = 'non-existing-worker-id'
		doThrow(NoSuchWorkerException).when(manager).removeWorker(any(String))

		// when
		val response = systemUnderTest.unregisterWorker(workerId)

		// then
		assertThat(response.status).isEqualTo(404)
		assertThat(response.getBody(String)).isEqualTo('Worker does not exist. It may have already been deleted.')
	}

	@Test
	def void workersCannotBeDeletedTwice() { // Note: DELETE should be idempotent, and it is (deleting multiple times does not change the server state).
	// The response is _not_ considered for idempotency, see 
	// given							//       https://stackoverflow.com/questions/24713945/does-idempotency-include-response-codes/24713946#24713946
		val worker = new WorkerClient(new URI('http://worker.example.org'), emptySet)
		when(manager.addWorker(any(WorkerClient))).thenReturn('http://worker.example.org')
		doNothing.doThrow(NoSuchWorkerException).when(manager).removeWorker(any(String))
		val registered = systemUnderTest.registerWorker(worker)
		val unregisterUrl = registered.stringHeaders.getFirst('Location') as String
		val workerId = unregisterUrl.substring(baseUrl.length)

		// when
		val firstResponse = systemUnderTest.unregisterWorker(workerId)
		val secondResponse = systemUnderTest.unregisterWorker(workerId)

		// then
		assertThat(firstResponse.status).isEqualTo(200)
		assertThat(secondResponse.status).isEqualTo(404)
		assertThat(secondResponse.getBody(String)).isEqualTo('Worker does not exist. It may have already been deleted.')
	}

	private def <T> T getBody(Response response, Class<T> type) {
		return try {
			response.readEntity(type)
		} catch (IllegalStateException ex) {
			response.entity as T
		}
	}

}
