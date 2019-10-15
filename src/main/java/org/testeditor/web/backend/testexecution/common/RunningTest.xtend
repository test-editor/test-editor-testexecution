package org.testeditor.web.backend.testexecution.common

interface RunningTest {

	def TestStatus checkStatus()

	def TestStatus waitForStatus()

	def void kill()

}
