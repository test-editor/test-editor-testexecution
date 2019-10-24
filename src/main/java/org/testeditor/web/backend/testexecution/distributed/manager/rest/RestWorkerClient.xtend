package org.testeditor.web.backend.testexecution.distributed.manager.rest

import com.fasterxml.jackson.annotation.JacksonInject
import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonProperty
import java.io.File
import java.io.InputStream
import java.net.URI
import java.util.Set
import java.util.concurrent.CompletionStage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.SynchronousQueue
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriBuilder
import org.apache.commons.io.FileUtils
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.RestClient
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.Worker

@Data
@EqualsHashCode
class RestWorkerClient implements Worker {
	public static val RestWorkerClient NONE = new RestWorkerClient(null)

	static val logger = LoggerFactory.getLogger(RestWorkerClient)

	val URI uri
	val Set<String> providedCapabilities
	val transient extension RestClient client
	val transient ExecutorService executor
	val transient currentJobs = <TestExecutionKey, SynchronousQueue<TestStatus>>newHashMap

	new(URI uri, Set<String> capabilities, RestClient client, ExecutorService executor) {
		this.uri = uri
		this.providedCapabilities = capabilities
		this.client = client
		this.executor = executor
	}

	@JsonCreator
	new(@JsonProperty('uri') URI uri, @JsonProperty('capabilities') Set<String> capabilities,
		@JacksonInject('restClient') RestClient client) {
		this(uri, capabilities, client, Executors.newSingleThreadExecutor)
	}

	new(URI uri) {
		this(uri, emptySet, null)
	}

	new(URI uri, Set<String> capabilities) {
		this(uri, capabilities, null)
	}

	override CompletionStage<TestStatus> startJob(TestJobInfo job) {
		currentJobs.put(job.id, new SynchronousQueue)

		return requestStartJob(job).thenApplyAsync[waitForCompletion(job)]
	}

	override checkStatus() {
		return TestStatus.valueOf(executor.submit [
			jobUri.build.getAsync(MediaType.TEXT_PLAIN_TYPE).toCompletableFuture.get.readEntity(String)
		].get)
	}

	override waitForStatus() {
		logger.info('''enqueueing request to wait for status of worker at "«uri»"''')
		return TestStatus.valueOf(executor.submit [
			logger.info('''now requesting to wait for status of worker at "«uri»"''')
			val status = jobUri.queryParam('wait', true).build.getAsync(MediaType.TEXT_PLAIN_TYPE).toCompletableFuture.
				get.readEntity(String)
			logger.info('''received status "«status»" of worker at "«uri»"''')
			return status
		].get)
	}

	override kill() {
		executor.submit [
			jobUri.build.deleteAsync
		]

	}

	def void updateStatus(TestExecutionKey key, TestStatus status) {
		if (status !== TestStatus.RUNNING) {
			currentJobs.remove(key)?.put(status)
		}
	}

	private def UriBuilder jobUri() {
		return UriBuilder.fromUri(uri).path('job')
	}

	private def CompletionStage<Boolean> requestStartJob(TestJobInfo job) {
		jobUri.build.postAsync(job).exceptionally [
			logger.error('''exception occurred while trying to assign job "«job?.id»" to worker at "«uri»"''', it)
			Response.serverError.entity('exception thrown on client side').build
		].thenApplyAsync [
			return (200 <= status && status < 300) => [ success |
				if (!success) {
					logger.
						warn('''job "«job?.id»" was rejected by worker at "«uri»" with status code «status»: «readEntity(String)»''')
				}
			]
		]
	}

	private def waitForCompletion(boolean successfullyStarted, TestJobInfo job) {
		if (successfullyStarted) {
			currentJobs.get(job.id).take
		} else {
			TestStatus.FAILED // TODO failed to start vs. test failed – separate status?
		}
	}

	override testJobExists(TestExecutionKey key) {
		return currentJobs.containsKey(key)
	}

	override getJsonCallTree(TestExecutionKey key) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}

	def downloadLogFile(TestExecutionKey key, File destDir) {
		val uri = UriBuilder.fromUri(uri).path('logs').path(key.suiteId).path(key.suiteRunId).build
		val logStream = uri.getAsync(MediaType.TEXT_PLAIN_TYPE).toCompletableFuture.get.readEntity(InputStream)
		return new File(destDir, '''testrun.«key.suiteId»-«key.suiteRunId»--.log''') => [ destFile |
			FileUtils.copyInputStreamToFile(logStream, destFile)
			logger.info('''saved log file for test job id "«key»" to file "«destFile.absolutePath»"''')
		]
	}

}
