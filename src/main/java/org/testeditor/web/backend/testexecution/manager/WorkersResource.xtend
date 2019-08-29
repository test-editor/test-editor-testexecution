package org.testeditor.web.backend.testexecution.manager

import javax.inject.Inject
import javax.ws.rs.DELETE
import javax.ws.rs.Encoded
import javax.ws.rs.POST
import javax.ws.rs.PUT
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.core.Context
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriInfo
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.worker.Worker
import org.testeditor.web.backend.testexecution.worker.WorkerResource

import static java.net.URLEncoder.encode
import static java.nio.charset.StandardCharsets.UTF_8

@Path('/testexecution/manager/workers')
class WorkersResource implements WorkersAPI {

	static val logger = LoggerFactory.getLogger(WorkerResource)

	@Inject
	TestExecutionManager manager

	@Inject
	extension UriAppender uriAppender
	
	@Context 
	UriInfo uriInfo

	@POST
	override Response registerWorker(Worker worker) {
		logger.info('''received request to register worker at "«worker.uri»"''')

		val workerId = manager.addWorker(worker)
		val location = uriInfo.append(encode(workerId, UTF_8))
		return Response.created(location).build
	}

	@Path('/{id}')
	@DELETE
	override Response unregisterWorker(@PathParam(value='id') @Encoded String id) {
		manager.removeWorker(id)
		return Response.ok.build
	}

	@Path('/{id}')
	@PUT
	def Response updateWorker(@PathParam(value='id') @Encoded String id) {
		manager.update(id)
		return Response.ok.build
	}

}
