package org.testeditor.web.backend.testexecution.manager

import java.net.URI

class WorkersResourceUnitTest extends WorkersAPITest {

	override getSystemUnderTest() {
		return new WorkersResource[__,toAppend | new URI(baseUrl + toAppend)]
	}
	
	override getBaseUrl() '''http://server.example.org/testexecution/manager/workers/'''	
}
