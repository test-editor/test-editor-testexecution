package org.testeditor.web.backend.testexecution.distributed.common

interface WorkerAPI<R> {
	
	def R isRegistered()

	def R executeTestJob(TestJob job)

	def R cancelTestJob()

	def R getTestJobState(Boolean wait)

}
