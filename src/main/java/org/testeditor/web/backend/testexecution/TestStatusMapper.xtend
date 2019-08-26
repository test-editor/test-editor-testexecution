package org.testeditor.web.backend.testexecution

import org.testeditor.web.backend.testexecution.worker.Worker

interface TestStatusMapper {

	def TestExecutionKey deriveFreshRunId(TestExecutionKey suiteKey)

	def TestStatus getStatus(TestExecutionKey executionKey)

	def TestStatus waitForStatus(TestExecutionKey executionKey)

	def void addTestSuiteRun(Worker worker, Process runningTestSuite)

	def void addTestSuiteRun(Worker worker, Process runningTestSuite, (TestStatus)=>void onCompleted)

	def Iterable<TestSuiteStatusInfo> getAllTestSuites()

	def void terminateTestSuiteRun(TestExecutionKey testExecutionKey)

}