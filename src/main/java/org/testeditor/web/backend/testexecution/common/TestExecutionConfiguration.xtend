package org.testeditor.web.backend.testexecution.common

interface TestExecutionConfiguration {
	def String getXvfbrunPath()
	def String getNicePath()
	def String getShPath()
	
	/**
     * Whether to skip over log entries produced by subordinate test steps.
     * 
     * When requesting the log lines for a particular test step via the
     * appropriate REST endpoint
     * ({@link org.testeditor.web.backend.testexecution.TestSuiteResource.xtend}),
     * log lines produced by sub-steps (and potentially their sub-steps) can
     * either be filtered out or kept.
     * 
     * If set to <code>true</code>, log lines associated with subordinate test
     * steps will get filtered out. If set to <code>false</code>, they will be
     * retained; lines marking the beginning and end of individual test steps
     * will still be removed, though.
     */
	def Boolean getFilterTestSubStepsFromLogs()
}
