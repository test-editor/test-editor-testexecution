package org.testeditor.web.backend.testexecution.worker

import org.testeditor.web.backend.testexecution.manager.TestJob
import javax.ws.rs.core.Response

interface WorkerAPI {
	
	def Response isRegistered()

	def Response executeTestJob(TestJob job)

	def Response cancelTestJob()

	def Response getTestJobState(Boolean wait)

}
