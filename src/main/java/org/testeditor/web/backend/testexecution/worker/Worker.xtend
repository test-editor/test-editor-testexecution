package org.testeditor.web.backend.testexecution.worker

import com.fasterxml.jackson.annotation.JacksonInject
import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonProperty
import java.net.URI
import java.util.Set
import java.util.concurrent.CompletionStage
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriBuilder
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.RunningTest
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import org.testeditor.web.backend.testexecution.manager.TestJob

import static javax.ws.rs.core.Response.Status.CREATED

@Data
@EqualsHashCode
class Worker implements RunningTest {

	public static val Worker NONE = new Worker(null)

	static val logger = LoggerFactory.getLogger(Worker)

	val URI uri
	val Set<String> capabilities
	val transient extension RestClient client

	@JsonCreator
	new(@JsonProperty('uri') URI uri, @JsonProperty('capabilities') Set<String> capabilities, @JacksonInject('restClient') RestClient client) {
		this.uri = uri
		this.capabilities = capabilities
		this.client = client
	}

	new(URI uri) {
		this(uri, emptySet, null)
	}

	new(URI uri, Set<String> capabilities) {
		this(uri, capabilities, null)
	}

	def CompletionStage<Boolean> startJob(TestJob job) {
		return jobUri.build.postAsync(job).exceptionally [
			logger.error('''exception occurred while trying to assign job "«job?.id»" to worker at "«uri»"''', it)
			Response.serverError.entity('exception thrown on client side').build
		].thenApplyAsync [
			return (status === CREATED.statusCode) => [ success |
				if (!success) {
					logger.warn('''job "«job?.id»" was rejected by worker at "«uri»" with status code «status»: «readEntity(String)»''')
				}
			]
		]
	}

	override checkStatus() {
		return TestStatus.valueOf(jobUri.build.get(MediaType.TEXT_PLAIN_TYPE).readEntity(String))
	}

	override waitForStatus() {
		val response = jobUri.queryParam('wait', true).build.get(MediaType.TEXT_PLAIN_TYPE)
		val body = response.readEntity(String)
		val status = TestStatus.valueOf(body)
		return status
	}

	override kill() {
		jobUri.build.delete
	}

	private def UriBuilder jobUri() {
		return UriBuilder.fromUri(uri).path('job')
	}

}
