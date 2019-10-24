package org.testeditor.web.backend.testexecution.distributed.common

import java.util.Set
import org.testeditor.web.backend.testexecution.common.TestExecutionKey

interface TestExecutionManager extends StatusAwareTestJobStore {

	def void cancelJob(TestExecutionKey key)

	def TestExecutionKey addJob(Iterable<String> testFiles, Set<String> requiredCapabilities)

}
