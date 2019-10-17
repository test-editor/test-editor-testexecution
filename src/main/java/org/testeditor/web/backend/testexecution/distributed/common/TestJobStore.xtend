package org.testeditor.web.backend.testexecution.distributed.common

import java.util.Optional
import org.testeditor.web.backend.testexecution.common.TestExecutionKey

interface TestJobStore {
	def boolean testJobExists(TestExecutionKey key)
	def Optional<String> getJsonCallTree(TestExecutionKey key)
}

interface WritableTestJobStore extends TestJobStore {
	def void store(TestJobInfo job)
}