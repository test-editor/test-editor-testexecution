package org.testeditor.web.backend.testexecution.distributed.common

import java.net.URI
import java.util.Set
import java.util.concurrent.CompletionStage
import org.testeditor.web.backend.testexecution.RunningTest

interface WorkerInfo {

	def URI getUri()

	def Set<String> getProvidedCapabilities()

}

interface Worker extends RunningTest, WorkerInfo {

	def CompletionStage<Boolean> startJob(TestJobInfo job)

}