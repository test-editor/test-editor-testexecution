package org.testeditor.web.backend.testexecution.common

interface GitConfiguration {
	def String getLocalRepoFileRoot()
	def String getRemoteRepoUrl()
	def String getBranchName()
	def String getPrivateKeyLocation()
	def String getKnownHostsLocation()
}
