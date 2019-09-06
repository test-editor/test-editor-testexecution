package org.testeditor.web.backend.testexecution.manager

import javax.inject.Inject
import javax.inject.Provider
import javax.ws.rs.core.Context
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriInfo
import javax.ws.rs.ext.ExceptionMapper
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.AlreadyRegisteredException
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.NoEligibleWorkerException
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.NoSuchJobException
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.NoSuchWorkerException
import org.testeditor.web.backend.testexecution.manager.TestExecutionManager.TestExecutionManagerException

import static java.net.URLEncoder.encode
import static java.nio.charset.StandardCharsets.UTF_8
import static javax.ws.rs.core.Response.Status.CONFLICT
import static javax.ws.rs.core.Response.Status.NOT_FOUND

class TestExecutionManagerExceptionMapper implements ExceptionMapper<TestExecutionManagerException> {

	Provider<UriAppender> uriAppender
	UriInfo uriInfo

	@Inject
	new(Provider<UriAppender> uriAppender, @Context UriInfo uriInfo) {
		this.uriAppender = uriAppender
		this.uriInfo = uriInfo
	}

	def dispatch Response toResponse(AlreadyRegisteredException it) {
		val location = uriAppender.get.append(uriInfo, encode(workerId, UTF_8))
		return Response.status(CONFLICT).entity('There is already a worker registered for this URL.').header('Location', location).build
	}

	def dispatch Response toResponse(NoSuchWorkerException it) {
		return Response.status(NOT_FOUND).entity('Worker does not exist. It may have already been deleted.').build
	}

	def dispatch Response toResponse(NoEligibleWorkerException it) {
		return Response.serverError.entity(it.message).build
	}

	def dispatch Response toResponse(NoSuchJobException it) {
		return Response.status(NOT_FOUND).entity(it.message).build
	}

}
