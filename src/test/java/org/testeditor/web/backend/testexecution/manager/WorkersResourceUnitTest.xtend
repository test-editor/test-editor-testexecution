package org.testeditor.web.backend.testexecution.manager

import java.io.InputStream
import javax.ws.rs.core.Response
import org.mockito.InjectMocks
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.TestExecutionManagerException

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
	
	
	override registerWorker(WorkerClient worker) {
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
	
	override upload(String workerId, TestExecutionKey jobId, String fileName, InputStream content) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override updateStatus(String workerId, TestExecutionKey jobId, TestStatus status) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
}
