package org.testeditor.web.backend.testexecution

interface TestExecutionConfiguration {
	def String getXvfbrunPath()
	def String getNicePath()
	def String getShPath()
	def Boolean getFilterTestSubStepsFromLogs()
}