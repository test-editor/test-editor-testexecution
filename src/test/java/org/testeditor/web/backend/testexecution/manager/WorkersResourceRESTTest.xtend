package org.testeditor.web.backend.testexecution.manager

import io.dropwizard.testing.junit.ResourceTestRule
import javax.ws.rs.client.Entity
import javax.ws.rs.core.Response
import org.junit.Rule
import org.testeditor.web.backend.testexecution.worker.Worker

class WorkersResourceRESTTest extends WorkersAPITest implements WorkersAPI {

	@Rule
	public val ResourceTestRule resources = ResourceTestRule.builder().addResource(new WorkersResource).build()

	override getSystemUnderTest() {
		return this
	}

	override getBaseUrl() {
		return resources.target('testexecution/manager/workers/').uri.toString
	}

	override Response registerWorker(Worker worker) {
		return resources.target('testexecution/manager/workers').request.post(Entity.json(worker))
	}

	override unregisterWorker(String id) {
		return resources.target('''testexecution/manager/workers/«id»''').request.delete
	}

}
