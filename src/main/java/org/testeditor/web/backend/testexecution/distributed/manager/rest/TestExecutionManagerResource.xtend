package org.testeditor.web.backend.testexecution.distributed.manager.rest

import javax.inject.Inject
import javax.ws.rs.POST
import javax.ws.rs.PUT
import javax.ws.rs.Path
import javax.ws.rs.core.Context
import javax.ws.rs.core.Response
import javax.ws.rs.core.UriInfo
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.manager.WritableWorkerProvider
import org.testeditor.web.backend.testexecution.util.UriAppender

import static java.net.URLEncoder.encode
import static java.nio.charset.StandardCharsets.UTF_8

@Path('/testexecution/manager/workers')
class TestExecutionManagerResource {
	static val logger = LoggerFactory.getLogger(TestExecutionManagerResource)

	@Inject
	extension WritableWorkerProvider<RestWorkerClient> workerProvider
	
	@Inject
	extension UriAppender uriAppender

	@Context
	UriInfo uriInfo

	@POST
	def registerWorker(RestWorkerClient worker) {
		logger.info('''received request to register worker at "«worker.uri»"''')

		worker.addWorker
		val location = uriInfo.append(encode(worker.uri.toString, UTF_8))
		return Response.created(location).build
	}

	@Path('/{workerId}/{jobId}')
	@PUT
	def updateStatus(String workerId, TestExecutionKey jobId, TestStatus status) {
		workerProvider.
		workers.filter(RestWorkerClient).findFirst[uri == workerId]?.updateStatus(jobId, status)
		return Response.ok.build
	}

}
