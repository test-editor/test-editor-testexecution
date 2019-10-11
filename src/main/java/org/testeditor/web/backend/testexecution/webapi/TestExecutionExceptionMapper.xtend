package org.testeditor.web.backend.testexecution.webapi

import javax.ws.rs.core.Response
import javax.ws.rs.ext.ExceptionMapper
import javax.ws.rs.ext.Provider
import org.testeditor.web.backend.testexecution.TestExecutionException

import static javax.ws.rs.core.MediaType.TEXT_PLAIN_TYPE
import static javax.ws.rs.core.Response.Status.INTERNAL_SERVER_ERROR

@Provider
class TestExecutionExceptionMapper implements ExceptionMapper<TestExecutionException> {

	override Response toResponse(TestExecutionException ex) {
		return Response.status(INTERNAL_SERVER_ERROR).entity(ex.toString).type(TEXT_PLAIN_TYPE).build
	}

}
