package org.testeditor.web.backend.testexecution.worker

import io.dropwizard.testing.junit.DropwizardClientRule
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.PrintWriter
import java.net.URI
import java.util.concurrent.Phaser
import javax.inject.Provider
import javax.ws.rs.Consumes
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.client.ClientBuilder
import javax.ws.rs.core.Response
import javax.ws.rs.core.StreamingOutput
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.glassfish.jersey.client.ClientConfig
import org.glassfish.jersey.client.ClientProperties
import org.glassfish.jersey.client.HttpUrlConnectorProvider
import org.glassfish.jersey.client.RequestEntityProcessing
import org.glassfish.jersey.client.rx.RxClient
import org.glassfish.jersey.client.rx.java8.RxCompletionStage
import org.glassfish.jersey.client.rx.java8.RxCompletionStageInvoker
import org.junit.Rule
import org.junit.Test
import org.testeditor.web.backend.testexecution.dropwizard.JerseyBasedRestClient
import org.testeditor.web.backend.testexecution.dropwizard.RestClient

import static java.nio.charset.StandardCharsets.UTF_8
import static org.assertj.core.api.Assertions.assertThat
import java.util.concurrent.TimeUnit

/**
 * Tests that RestClient can post data as chunked stream.
 * 
 * For this, a dummy resource is created and "hosted" by a DropwizardClientRule.
 * The test continually writes data to a stream, which the dummy resource on the server side receives in chunks.
 * For this, the client needs to set REQUEST_ENTITY_PROCESSING to CHUNKED, otherwise the payload will be buffered
 * instead of being sent as a stream.
 * To test that neither the client is waiting that its write buffer fills up, nor the server is waiting to receive
 * the complete payload before continuing to process it, the two corresponding threads are interlocked using a
 * phaser. This forces them to wait on each other: the client writes a single line to the stream, flushes it, and
 * then waits for the server to receive and process that line. Once the server has done this, the current phase
 * ends and the client continues with the next phase, i.e. writing the next line to the stream.
 */
class RestClientStreamingTest {

	val phaser = new Phaser(2)

	@FinalFieldsConstructor
	@Path('/receive')
	static class TestResource {

		val Phaser phaser

		@POST
		@Consumes('*/*')
		def Response receiveStreamingData(InputStream stream) {

			new BufferedReader(new InputStreamReader(stream, UTF_8)).lines.forEach [
				phaser.arriveAndAwaitAdvance
			]
			phaser.arriveAndDeregister
			return Response.ok.build
		}

	}

	val resource = new TestResource(phaser)

	@Rule
	public val DropwizardClientRule clientRule = new DropwizardClientRule(resource)

	Provider<RxClient<RxCompletionStageInvoker>> rxClientProvider = [
		val HttpUrlConnectorProvider connectorProvider = new HttpUrlConnectorProvider
		val clientConfig = new ClientConfig().connectorProvider(connectorProvider)
		clientConfig.property(ClientProperties.REQUEST_ENTITY_PROCESSING, RequestEntityProcessing.CHUNKED)
		RxCompletionStage.from(ClientBuilder.newClient(clientConfig))
	]

	RestClient client = new JerseyBasedRestClient(rxClientProvider)

	@Test
	def void streamsDataContinuously() {
		// given
		val uri = new URI(clientRule.baseUri + '/receive')
		val stream = [ OutputStream out |
			val startTime = System.currentTimeMillis
			new PrintWriter(out) => [
				while (System.currentTimeMillis - startTime < 10000) {
					write('all work and no play makes Jack a dull boy\n')
					flush
					phaser.arriveAndAwaitAdvance
				}
				close
				phaser.arriveAndDeregister
			]
		] as StreamingOutput

		// when
		client.postAsync(uri, stream) //
		//
		// then
		.thenAccept [
			assertThat(status).isEqualTo(200)
		].toCompletableFuture.orTimeout(15, TimeUnit.SECONDS).join
	}

}
