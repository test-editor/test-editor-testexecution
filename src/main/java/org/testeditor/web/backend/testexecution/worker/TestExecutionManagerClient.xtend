package org.testeditor.web.backend.testexecution.worker

import java.io.InputStream
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Provider
import javax.inject.Singleton
import javax.ws.rs.core.Response.Status
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestStatus
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration
import org.testeditor.web.backend.testexecution.manager.WorkerClient

@Singleton
class TestExecutionManagerClient {
	static val logger = LoggerFactory.getLogger(TestExecutionManagerClient)

	val registrationScheduler = Executors.newSingleThreadScheduledExecutor
	var ScheduledFuture<?> registrationTask
	var registrationRetries = 0

	@Inject
	Provider<RestClient> client

	@Inject
	extension TestExecutionDropwizardConfiguration

	def void registerWorker(WorkerClient worker) {
		registrationRetries = 0
		registrationTask = registrationScheduler.scheduleWithFixedDelay([tryRegistration(worker)], 0,
			registrationRetryIntervalSecs, TimeUnit.SECONDS)
	}

	def void unregisterWorker(String id) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}

	def void upload(String workerId, TestExecutionKey jobId, String fileName, InputStream content) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}

	def void updateStatus(String workerId, TestExecutionKey jobId, TestStatus status) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}

	private def void tryRegistration(WorkerClient worker) {
		if (registrationRetries++ < registrationMaxRetries) {
			logger.info('''trying to register with test execution manager at "«testExecutionManagerUrl»"''')
			val response = client.get.postAsync(testExecutionManagerUrl, worker).toCompletableFuture.join
			if (response.statusInfo == Status.CREATED) {
				logger.info('''successfully registered at "«response.location.toString»"''')
				registrationTask.cancel(false)
			} else if (response.statusInfo == Status.CONFLICT) {
				val message = response.readEntity(String)
				logger.warn('''test execution manager already has a worker registered at "«worker.uri»"; message: «message»''')
				registrationTask.cancel(false)
			} else {
				logger.warn('''registration with test execution manager failed, retry in «registrationRetryIntervalSecs» seconds''')
			}
		} else {
			logger.warn('''giving up registering with test execution manager after «registrationRetries» attempts''')
			registrationTask.cancel(false)
		}
	}

}
