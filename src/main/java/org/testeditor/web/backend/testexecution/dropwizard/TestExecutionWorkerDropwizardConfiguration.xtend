package org.testeditor.web.backend.testexecution.dropwizard

import java.net.URI
import java.net.URL
import org.eclipse.xtend.lib.annotations.Accessors
import org.testeditor.web.backend.testexecution.distributed.worker.WorkerConfiguration

@Accessors
class TestExecutionWorkerDropwizardConfiguration extends TestExecutionDropwizardConfiguration implements WorkerConfiguration {
	int registrationRetryIntervalSecs = 30
	int registrationMaxRetries = 10
	URI testExecutionManagerUrl
	URL workerUrl = new URL('http://localhost')
}
