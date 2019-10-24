package org.testeditor.web.backend.testexecution.distributed.common

import java.net.URI
import java.util.Set
import java.util.concurrent.CompletionStage
import org.testeditor.web.backend.testexecution.common.RunningTest
import org.testeditor.web.backend.testexecution.common.TestStatus

interface WorkerInfo {

	def URI getUri()

	def Set<String> getProvidedCapabilities()
	
	def String id() '''«uri.toString»'''

	static val NONE = new WorkerInfo {
		val uri = new URI('')
		val providedCapabilities = <String>emptySet
		
		override getUri() { uri }
		
		override getProvidedCapabilities() { providedCapabilities }
		
	}

}

interface Worker extends RunningTest, WorkerInfo, TestJobStore {

	def CompletionStage<TestStatus> startJob(TestJobInfo job)

}
