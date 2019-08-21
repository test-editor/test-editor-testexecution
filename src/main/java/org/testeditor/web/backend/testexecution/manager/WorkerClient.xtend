package org.testeditor.web.backend.testexecution.manager

import javax.inject.Inject
import javax.inject.Singleton
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import org.testeditor.web.backend.testexecution.worker.Worker

@Singleton
class WorkerClient {

	@Inject
	RestClient client

	def executeTestJob(Worker worker, TestJob job) {
		client.post(worker.url, job).whenCompleteAsync[response, error |
			
		]
	}

}
