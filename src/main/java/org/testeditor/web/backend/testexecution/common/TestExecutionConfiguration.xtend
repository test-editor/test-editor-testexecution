package org.testeditor.web.backend.testexecution.common

interface TestExecutionConfiguration {
	def String getXvfbrunPath()
	def String getNicePath()
	def String getShPath()
	
	def int getLongPollingTimeoutSeconds()
	
	/**
	 * Maximum number of already executed test jobs to be kept in memory.
	 * 
	 * This only keeps basic test execution information, like which tests belong to the job, and what the execution status was, in memory.
	 * On a cache miss, the information will be restored from the test execution's call tree yaml file.
	 */
	def int getTestJobCacheSize()
	/**
	 * Maximum number of complete call trees of already executed test jobs to be kept in memory.
	 * 
	 * This comprises the full details contained in test execution call trees. 
	 * It does not include log data or screenshots.
	 */
	def int getTestJobCallTreeCacheSize()
	
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
