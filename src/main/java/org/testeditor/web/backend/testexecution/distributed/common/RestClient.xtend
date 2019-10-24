package org.testeditor.web.backend.testexecution.distributed.common

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import java.net.URI
import java.util.concurrent.CompletionStage
import java.util.concurrent.ExecutorService
import java.util.concurrent.ForkJoinPool
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Provider
import javax.inject.Singleton
import javax.ws.rs.client.Entity
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.StreamingOutput
import org.glassfish.jersey.client.rx.RxClient
import org.glassfish.jersey.client.rx.java8.RxCompletionStageInvoker
import org.slf4j.LoggerFactory

import static javax.ws.rs.client.Entity.json
import static javax.ws.rs.core.MediaType.APPLICATION_JSON_TYPE
import static org.glassfish.jersey.client.ClientProperties.READ_TIMEOUT
import static org.glassfish.jersey.client.ClientProperties.CONNECT_TIMEOUT
import static org.glassfish.jersey.client.HttpUrlConnectorProvider.USE_FIXED_LENGTH_STREAMING

/**
 * Abstraction around an HTTP client for easy mocking
 */
interface RestClient {

	public static val int READ_TIMEOUT_MILLIS = 10000

	def <T> CompletionStage<Response> postAsync(URI uri, T body)

	def CompletionStage<Response> postAsync(URI uri, StreamingOutput body)

	def <T> CompletionStage<Response> putAsync(URI uri, T body)

	def <T> CompletionStage<Response> getAsync(URI uri)

	def <T> CompletionStage<Response> getAsync(URI uri, MediaType accept)

	def <T> CompletionStage<Response> deleteAsync(URI uri)

	def <T> Response post(URI uri, T body)

	def <T> Response put(URI uri, T body)

	def <T> Response get(URI uri)

	def <T> Response get(URI uri, MediaType accept)

	def <T> Response delete(URI uri)

}

abstract class AbstractRestClient implements RestClient {

	override <T> post(URI uri, T body) {
		return uri.postAsync(body).toCompletableFuture.join
	}

	override <T> put(URI uri, T body) {
		return uri.putAsync(body).toCompletableFuture.join
	}

	override <T> get(URI uri) {
		return uri.getAsync.toCompletableFuture.join
	}

	override <T> delete(URI uri) {
		return uri.deleteAsync.toCompletableFuture.join
	}

	override <T> get(URI uri, MediaType accept) {
		return uri.getAsync(accept).toCompletableFuture.join
	}

}

@Singleton
class JerseyBasedRestClient extends AbstractRestClient {

	static val logger = LoggerFactory.getLogger(JerseyBasedRestClient)

	val Provider<RxClient<RxCompletionStageInvoker>> httpClientProvider
	val ExecutorService executor

	@Inject
	new(Provider<RxClient<RxCompletionStageInvoker>> httpClientProvider, @Named('httpClientExecutor') ForkJoinPool executor) {
		this.httpClientProvider = httpClientProvider
		this.executor = executor
	}

	override <T> CompletionStage<Response> postAsync(URI uri, T body) {
		val entity = json(body)
		logger.info('''sending POST request to «uri.toString» with body:\n«entity.toString»''')
		return uri.invoker.post(entity)
	}

	override CompletionStage<Response> postAsync(URI uri, StreamingOutput body) {
		val entity = Entity.entity(body, MediaType.APPLICATION_OCTET_STREAM_TYPE)
		logger.info('''sending POST request to «uri.toString» with streaming data''')
		return uri.streamingInvoker.post(entity)
	}

	override <T> CompletionStage<Response> putAsync(URI uri, T body) {
		val entity = json(body)
		logger.info('''sending PUT request to «uri.toString» with body:\n«entity.toString»''')
		return uri.invoker.put(entity)
	}

	override <T> CompletionStage<Response> getAsync(URI uri) {
		return uri.invoker.get
	}

	override <T> CompletionStage<Response> getAsync(URI uri, MediaType accept) {
		return uri.getInvoker(accept).get
	}

	override <T> deleteAsync(URI uri) {
		return uri.invoker.delete
	}

	private def getInvoker(URI uri) {
		return uri.getInvoker(APPLICATION_JSON_TYPE)
	}

	private def getInvoker(URI uri, MediaType accept) {
		return httpClientProvider.get.property(READ_TIMEOUT, READ_TIMEOUT_MILLIS).target(uri).request(accept).header(
			'Authorization', '''Bearer «dummyToken»''').rx(executor)
	}

	private def getStreamingInvoker(URI uri) {
		return httpClientProvider.get.property(USE_FIXED_LENGTH_STREAMING, true).property(READ_TIMEOUT, 0).property(CONNECT_TIMEOUT, 0).target(uri).
			request.header('Authorization', '''Bearer «dummyToken»''').rx(executor)
	}

	val static String dummyToken = createToken('test.execution', 'Test Execution User', 'testeditor.eng@gmail.com')

	static def String createToken(String id, String name, String eMail) {
		val builder = JWT.create => [
			withClaim('id', id)
			withClaim('name', name)
			withClaim('email', eMail)
		]
		return builder.sign(Algorithm.HMAC256("secret"))
	}

}
