package org.testeditor.web.backend.testexecution

import io.dropwizard.jersey.errors.LoggingExceptionMapper
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.InputStream
import javax.inject.Inject
import javax.ws.rs.GET
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.Produces
import javax.ws.rs.core.Context
import javax.ws.rs.core.HttpHeaders
import javax.ws.rs.core.MediaType
import javax.ws.rs.core.Response
import javax.ws.rs.ext.Provider
import org.testeditor.web.backend.testexecution.manager.MaliciousPathException
import org.testeditor.web.backend.testexecution.manager.ManagerWorkspaceProvider
import org.testeditor.web.backend.testexecution.manager.MissingFileException
import org.testeditor.web.backend.testexecution.manager.TestArtifactAccessException

import static javax.ws.rs.core.Response.Status.OK
import static javax.ws.rs.core.Response.status

import static extension java.nio.file.Files.probeContentType

@Path("/documents/{resourcePath:.*}")
@Produces(MediaType.TEXT_PLAIN)
class TestArtifactResource {

	@Inject ManagerWorkspaceProvider workspaceProvider

	@GET
	def Response loadLocal(@PathParam("resourcePath") String resourcePath, @Context HttpHeaders headers) {
			return status(OK).entity(loadLocal(resourcePath)).type(getType(resourcePath)).build
	}
	
	def InputStream loadLocal(String resourcePath) throws FileNotFoundException {
		return new FileInputStream(workspaceProvider.getLocalWorkspaceFile(resourcePath))
	}
	
	def String getType(String resourcePath) {
		val file = workspaceProvider.getLocalWorkspaceFile(resourcePath)
		return file.toPath.probeContentType
	}

}

@Provider
class TestArtifactAccessExceptionMapper extends LoggingExceptionMapper<TestArtifactAccessException> {

	def dispatch Response toResponse(MaliciousPathException e) {
		val logId = logException(e)
		val message = String.format("You are not allowed to access this resource. Your attempt has been logged (ID %016x).", logId);
		return Response.status(Response.Status.FORBIDDEN).entity(message).build
	}

	def dispatch Response toResponse(MissingFileException missingFileException) {
		logException(missingFileException)

		return Response.status(Response.Status.NOT_FOUND).entity(missingFileException.message).build
	}

}
