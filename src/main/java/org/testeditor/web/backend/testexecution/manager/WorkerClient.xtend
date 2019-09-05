package org.testeditor.web.backend.testexecution.manager

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
import org.testeditor.web.backend.testexecution.manager.TestJobInfo

import static javax.ws.rs.core.Response.Status.CREATED
import java.util.concurrent.CompletableFuture

interface WorkerInfo {

	def URI getUri()

	def Set<String> getProvidedCapabilities()

}

interface OperableWorker extends RunningTest, WorkerInfo {

	def CompletionStage<Boolean> startJob(TestJobInfo job)

}

@Data
@EqualsHashCode
class WorkerClient implements OperableWorker {

	public static val WorkerClient NONE = new WorkerClient(null)

	static val logger = LoggerFactory.getLogger(WorkerClient)

	val URI uri
	val Set<String> providedCapabilities
	val transient extension RestClient client
	var transient CompletionStage<?> asyncCallStage = CompletableFuture.completedStage(null)

	@JsonCreator
	new(@JsonProperty('uri') URI uri, @JsonProperty('capabilities') Set<String> capabilities, @JacksonInject('restClient') RestClient client) {
		this.uri = uri
		this.providedCapabilities = capabilities
		this.client = client
	}

	new(URI uri) {
		this(uri, emptySet, null)
	}

	new(URI uri, Set<String> capabilities) {
		this(uri, capabilities, null)
	}

	override CompletionStage<Boolean> startJob(TestJobInfo job) {
		synchronized (asyncCallStage) {
			val result = asyncCallStage.thenCompose [
				jobUri.build.postAsync(job).exceptionally [
					logger.error('''exception occurred while trying to assign job "«job?.id»" to worker at "«uri»"''', it)
					Response.serverError.entity('exception thrown on client side').build
				].thenApplyAsync [
					return (status === CREATED.statusCode) => [ success |
						if (!success) {
							logger.warn('''job "«job?.id»" was rejected by worker at "«uri»" with status code «status»: «readEntity(String)»''')
						}
					]
				]
			]
			asyncCallStage = result
			return result
		}
	}

	override checkStatus() {
		synchronized (asyncCallStage) {
			val result = asyncCallStage.thenCompose[jobUri.build.getAsync(MediaType.TEXT_PLAIN_TYPE)]
			asyncCallStage = result
			return TestStatus.valueOf(result.toCompletableFuture.get.readEntity(String))
		}
	}

	override waitForStatus() {
		synchronized (asyncCallStage) {
			val result = asyncCallStage.thenCompose[jobUri.queryParam('wait', true).build.getAsync(MediaType.TEXT_PLAIN_TYPE)]
			asyncCallStage = result
			return TestStatus.valueOf(result.toCompletableFuture.get.readEntity(String))
		}
	}

	override kill() {
		synchronized (asyncCallStage) {
			asyncCallStage = asyncCallStage.thenCompose[jobUri.build.deleteAsync]
		}
	}

	private def UriBuilder jobUri() {
		return UriBuilder.fromUri(uri).path('job')
	}

}
