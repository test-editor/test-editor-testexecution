package org.testeditor.web.backend.testexecution.manager

import javax.inject.Inject
import javax.ws.rs.DELETE
import javax.ws.rs.Encoded
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.core.Response
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.worker.Worker
import org.testeditor.web.backend.testexecution.worker.WorkerResource

import static java.net.URLEncoder.encode
import static java.nio.charset.StandardCharsets.UTF_8

@Path('/testexecution/manager/workers')
class WorkersResource extends AbstractResource implements WorkersAPI {

	static val logger = LoggerFactory.getLogger(WorkerResource)

	@Inject
	extension TestExecutionManager manager

	new() {
		super()
	}

	new(UriAppender uriAppender) {
		super(uriAppender)
	}

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

}
