package org.testeditor.web.backend.testexecution

interface RunningTest {

	def TestStatus checkStatus()

	def TestStatus waitForStatus()

	def void kill()

}
