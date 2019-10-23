package org.testeditor.web.backend.testexecution.distributed.worker

import java.net.URI
import java.net.URL

interface WorkerConfiguration {
	def URL getWorkerUrl()

	def int getRegistrationRetryIntervalSecs()

	def int getRegistrationMaxRetries()

	def URI getTestExecutionManagerUrl()
}
