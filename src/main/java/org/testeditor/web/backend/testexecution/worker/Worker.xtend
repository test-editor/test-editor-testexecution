package org.testeditor.web.backend.testexecution.worker

import java.net.URI
import java.util.HashSet
import java.util.Set
import javax.inject.Inject
import javax.ws.rs.core.UriBuilder
import org.eclipse.xtend.lib.annotations.Accessors
import org.testeditor.web.backend.testexecution.RunningTest
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import java.util.Collections

@Accessors
class Worker implements RunningTest {

	@Accessors(NONE)
	@Inject transient extension RestClient

	URI uri
	Set<String> capabilities
	TestExecutionKey job

	new() {
	}

	def Worker copy() {
		return new Worker => [
			it.uri = this.uri
			it.capabilities = if (this.capabilities === null) {
				null
			} else {
				new HashSet(this.capabilities)
			}
			it.job = this.job?.copy
		]
	}

	override checkStatus() {
		return jobUri.build.get.readEntity(TestStatus)
	}

	override waitForStatus() {
		return jobUri.queryParam('wait').build.get.readEntity(TestStatus)
	}

	override kill() {
		jobUri.build.delete
	}

	private def UriBuilder jobUri() {
		return UriBuilder.fromUri(uri).path('job')
	}

}
