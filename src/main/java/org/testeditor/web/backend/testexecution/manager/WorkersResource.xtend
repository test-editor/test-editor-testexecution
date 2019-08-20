package org.testeditor.web.backend.testexecution.manager

import java.util.Map
import java.util.concurrent.ConcurrentHashMap
import javax.ws.rs.DELETE
import javax.ws.rs.POST
import javax.ws.rs.Path
import javax.ws.rs.PathParam
import javax.ws.rs.core.Response
import org.testeditor.web.backend.testexecution.worker.Worker

import static java.net.URLEncoder.encode
import static java.nio.charset.StandardCharsets.UTF_8
import static javax.ws.rs.core.Response.Status.CONFLICT
import static javax.ws.rs.core.Response.Status.NOT_FOUND
import javax.ws.rs.Encoded

@Path('/testexecution/manager/workers')
class WorkersResource extends AbstractResource implements WorkersAPI {

	new() {
		super()
	}

	new(UriAppender uriAppender) {
		super(uriAppender)
	}

	Map<String, Worker> workers = new ConcurrentHashMap

	@POST
	override Response registerWorker(Worker worker) {
		val workerId = encode(worker.url.toString, UTF_8)
		val location = uriInfo.append(workerId)
		return if (workers.containsKey(workerId)) {
			Response.status(CONFLICT).entity('There is already a worker registered for this URL.').header('Location', location).build
		} else {
			workers.put(workerId, worker)
			Response.created(location).build
		}
	}

	@Path('/{id}')
	@DELETE
	override Response unregisterWorker(@PathParam(value='id') @Encoded String id) {
		return if (workers.containsKey(id)) {
			workers.remove(id)
			Response.ok.build
		} else {
			Response.status(NOT_FOUND).entity('Worker does not exist. It may have already been deleted.').build
		}
	}

}
