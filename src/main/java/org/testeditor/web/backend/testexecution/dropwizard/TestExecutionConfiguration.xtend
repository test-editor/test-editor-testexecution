package org.testeditor.web.backend.testexecution.dropwizard

interface TestExecutionConfiguration {
	def String getXvfbrunPath()
	def String getNicePath()
	def String getShPath()
	def Boolean getFilterTestSubStepsFromLogs()
}
