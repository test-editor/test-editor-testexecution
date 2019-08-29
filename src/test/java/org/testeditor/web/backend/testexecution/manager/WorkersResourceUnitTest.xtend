package org.testeditor.web.backend.testexecution.manager

import javax.ws.rs.core.Response
import org.mockito.InjectMocks
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.TestExecutionManagerException
import org.testeditor.web.backend.testexecution.worker.Worker

/**
 * Tests the contract of WorkersResource in conjunction with the TestExecutionManagerExceptionMapper.
 * 
 * Strictly speaking, this is not a pure unit test then, but it does mock WorkerResource's direct
 * dependencies, and uses the exposed Java API directly, as opposed to the JAX-RS-based REST interface.
 */
class WorkersResourceUnitTest extends WorkersAPITest implements WorkersAPI {
	
	@InjectMocks
	extension val TestExecutionManagerExceptionMapper exceptionMapper = new TestExecutionManagerExceptionMapper

	override getSystemUnderTest() {
		return this
	}
	
	override getBaseUrl() '''http://server.example.org/testexecution/manager/workers/'''
	
	
	override registerWorker(Worker worker) {
		return mapException[workersResource.registerWorker(worker)]
	}
	
	override unregisterWorker(String id) {
		return mapException[workersResource.unregisterWorker(id)]
	}
	
	private def Response mapException(()=>Response method) {
		return try {
			method.apply
		} catch (TestExecutionManagerException ex) {
			toResponse(ex)
		}
	}
	
}
