package org.testeditor.web.backend.testexecution.distributed.common

import java.util.Map
import java.util.Optional
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus

interface TestJobStore {
	def boolean testJobExists(TestExecutionKey key)
	def Optional<String> getJsonCallTree(TestExecutionKey key)
}

interface WritableTestJobStore extends TestJobStore {
	def void store(TestJobInfo job)
}

interface TestJobStatusMapper {
	def Map<TestExecutionKey,TestStatus> getStatusAll()
	def TestStatus getStatus(TestExecutionKey key)
	def TestStatus waitForStatus(TestExecutionKey key)
}

interface StatusAwareTestJobStore extends TestJobStore, TestJobStatusMapper {}

interface WritableStatusAwareTestJobStore extends WritableTestJobStore, TestJobStatusMapper {}