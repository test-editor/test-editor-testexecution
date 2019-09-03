package org.testeditor.web.backend.testexecution

interface TestStatusMapper {

	def TestExecutionKey deriveFreshRunId(TestExecutionKey suiteKey)

	def TestStatus getStatus(TestExecutionKey executionKey)

	def TestStatus waitForStatus(TestExecutionKey executionKey)

	def void addTestSuiteRun(TestExecutionKey job, RunningTest worker)

	def void addTestSuiteRun(TestExecutionKey job, RunningTest worker, (TestStatus)=>void onCompleted)

	def Iterable<TestSuiteStatusInfo> getAllTestSuites()

	def void terminateTestSuiteRun(TestExecutionKey testExecutionKey)

}