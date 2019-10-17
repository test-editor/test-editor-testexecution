package org.testeditor.web.backend.testexecution.distributed.manager

import com.google.common.cache.CacheBuilder
import java.io.File
import java.util.List
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Provider
import org.testeditor.web.backend.testexecution.TestExecutionCallTree
import org.testeditor.web.backend.testexecution.common.TestExecutionConfiguration
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.WritableTestJobStore
import org.testeditor.web.backend.testexecution.util.serialization.YamlReader

class LocalSingleWorkerJobStore implements WritableTestJobStore {
	@Inject extension YamlReader
	@Inject extension TestExecutionCallTree callTreeHelper
	@Inject @Named('workspace') Provider<File> workspaceProvider
	
	private def workspace() { workspaceProvider.get }
	
	@Inject Provider<TestExecutionConfiguration> config
	val jobCache = CacheBuilder.newBuilder.maximumSize(1000).<TestExecutionKey, TestJobInfo>build[key|
		callTreeMap.get(key)
		/* TODO capabilities need to be stored in call tree yaml! */
		.map[new TestJob(key, #{}, getOrDefault('resourcePaths',#[]) as List<String>)]
		.orElse(TestJob.NONE)
	]
	
	val callTreeMap = CacheBuilder.newBuilder.maximumSize(1000).build[TestExecutionKey key|
		key.getLatestCallTree(workspace).map[readYaml]
	]
	
	override testJobExists(TestExecutionKey key) {
		jobCache.get(key.deriveWithSuiteRunId) != TestJob.NONE
	}
	
	override getJsonCallTree(TestExecutionKey key) {
		if (key.caseRunId.nullOrEmpty) {
			callTreeMap.get(key).map[key.getCompleteTestCallTreeJson[it]]
		} else {
			callTreeMap.get(key.deriveWithSuiteRunId).map[key.getNodeJson[it]]
		}
		
	}
	
	override store(TestJobInfo job) {
		jobCache.put(job.id, job)
	}
	
}