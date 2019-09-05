package org.testeditor.web.backend.testexecution.manager

import io.dropwizard.jackson.Jackson
import io.dropwizard.testing.junit.ResourceTestRule
import java.io.InputStream
import javax.inject.Provider
import javax.ws.rs.client.Entity
import javax.ws.rs.core.Response
import org.glassfish.hk2.utilities.binding.AbstractBinder
import org.junit.Rule
import org.mockito.Mock
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.dropwizard.InjectableValueProviderMap
import org.testeditor.web.backend.testexecution.dropwizard.RestClient

class WorkersResourceRESTTest extends WorkersAPITest implements WorkersAPI {
	
	
	@Mock
	RestClient restClient

	@Rule
	public val ResourceTestRule resources = (ResourceTestRule.builder() => [
		addProvider(TestExecutionManagerExceptionMapper)
		addResource(workersResource)
		addResource(new AbstractBinder() {

			override protected configure() {
				bind(manager).to(TestExecutionManager)
				bind(appender).to(UriAppender)
			}

		})
		mapper = Jackson.newObjectMapper => [
			injectableValues = new InjectableValueProviderMap(#{'restClient' -> [restClient] as Provider<RestClient>})
		]
	]).build()

	override getSystemUnderTest() {
		return this
	}

	override getBaseUrl() {
		return resources.target('testexecution/manager/workers/').uri.toString
	}

	override Response registerWorker(WorkerClient worker) {
		return resources.target('testexecution/manager/workers').request.post(Entity.json(worker))
	}

	override unregisterWorker(String id) {
		return resources.target('''testexecution/manager/workers/«id»''').request.delete
	}
	
	override upload(String workerId, TestExecutionKey jobId, String fileName, InputStream content) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override updateStatus(String workerId, TestExecutionKey jobId, TestStatus status) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}

}
