package org.testeditor.web.backend.testexecution.dropwizard

import java.net.URL
import java.util.concurrent.CompletionStage
import javax.inject.Singleton
import javax.ws.rs.client.Entity
import org.glassfish.jersey.client.rx.RxClient
import org.glassfish.jersey.client.rx.java8.RxCompletionStageInvoker

import static javax.ws.rs.core.MediaType.APPLICATION_JSON_TYPE
import javax.ws.rs.core.Response


/**
 * Abstraction around an HTTP client for easy mocking
 */
 interface RestClient {
 	def <T> CompletionStage<Response> post(URL url, T body)
 }
@Singleton
class JerseyBasedRestClient implements RestClient {

	RxClient<RxCompletionStageInvoker> httpClient

	override <T> CompletionStage<Response> post(URL url, T body) {
		return httpClient.target(url.toURI).request(APPLICATION_JSON_TYPE).rx.post(Entity.entity(body, APPLICATION_JSON_TYPE))
	}	
}