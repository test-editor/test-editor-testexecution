package org.testeditor.web.backend.testexecution.manager

import io.dropwizard.jackson.Jackson
import io.dropwizard.testing.junit.ResourceTestRule
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import javax.inject.Provider
import javax.ws.rs.client.Entity
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.StreamingOutput
import org.glassfish.hk2.utilities.binding.AbstractBinder
import org.junit.Rule
import org.mockito.Mock
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.dropwizard.InjectableValueProviderMap
import org.testeditor.web.backend.testexecution.dropwizard.RestClient

import static java.net.URLEncoder.encode
import static java.nio.charset.StandardCharsets.UTF_8

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
				bind(workspace.root).to(File).named('workspace')
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
		val streamingContent = [ OutputStream out |
			content.transferTo(out)
		] as StreamingOutput
		val payload = Entity.entity(streamingContent, MediaType.APPLICATION_OCTET_STREAM_TYPE)
		return resources.target('''testexecution/manager/workers/«encode(workerId, UTF_8)»/«jobId»/«encode(fileName, UTF_8)»''').request.post(payload)
	}
	
	override updateStatus(String workerId, TestExecutionKey jobId, TestStatus status) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}

}
