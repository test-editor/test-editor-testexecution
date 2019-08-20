package org.testeditor.web.backend.testexecution.manager

import javax.ws.rs.core.Response
import org.testeditor.web.backend.testexecution.worker.Worker

interface WorkersAPI {

	def Response registerWorker(Worker worker)

	def Response unregisterWorker(String id)

}
