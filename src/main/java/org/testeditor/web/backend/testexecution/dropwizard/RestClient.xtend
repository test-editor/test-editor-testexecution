package org.testeditor.web.backend.testexecution.dropwizard

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import java.net.URI
import java.util.concurrent.CompletionStage
import javax.inject.Inject
import javax.inject.Provider
import javax.inject.Singleton
import javax.ws.rs.client.Entity
import javax.ws.rs.core.Response
import org.glassfish.jersey.client.rx.RxClient
import org.glassfish.jersey.client.rx.java8.RxCompletionStageInvoker

import static javax.ws.rs.core.MediaType.APPLICATION_JSON_TYPE

/**
 * Abstraction around an HTTP client for easy mocking
 */
interface RestClient {

	def <T> CompletionStage<Response> postAsync(URI uri, T body)

	def <T> CompletionStage<Response> getAsync(URI uri)

	def <T> CompletionStage<Response> deleteAsync(URI uri)

	def <T> Response post(URI uri, T body)

	def <T> Response get(URI uri)

	def <T> Response delete(URI uri)

}

abstract class AbstractRestClient implements RestClient {

	override <T> post(URI uri, T body) {
		return uri.postAsync(body).toCompletableFuture.join
	}

	override <T> get(URI uri) {
		return uri.getAsync.toCompletableFuture.join
	}
	
	override <T> delete(URI uri) {
		return uri.deleteAsync.toCompletableFuture.join
	}

}

@Singleton
class JerseyBasedRestClient extends AbstractRestClient {

	@Inject
	Provider<RxClient<RxCompletionStageInvoker>> httpClientProvider

	override <T> CompletionStage<Response> postAsync(URI uri, T body) {
		return uri.invoker.post(Entity.entity(body, APPLICATION_JSON_TYPE))
	}

	override <T> CompletionStage<Response> getAsync(URI uri) {
		return uri.invoker.get
	}

	override <T> deleteAsync(URI uri) {
		return uri.invoker.delete
	}

	private def getInvoker(URI uri) {
		return httpClientProvider.get.target(uri).request(APPLICATION_JSON_TYPE).header('Authorization', '''Bearer «dummyToken»''').rx
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
