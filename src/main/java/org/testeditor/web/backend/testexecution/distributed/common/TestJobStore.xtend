package org.testeditor.web.backend.testexecution.distributed.common

import org.testeditor.web.backend.testexecution.common.TestExecutionKey

interface TestJobStore {
	def boolean testJobExists(TestExecutionKey key)
	def String getJsonCallTree(TestExecutionKey key)
}

interface WritableTestJobStore extends TestJobStore {
	def void store(TestExecutionKey key, TestJob job)
}