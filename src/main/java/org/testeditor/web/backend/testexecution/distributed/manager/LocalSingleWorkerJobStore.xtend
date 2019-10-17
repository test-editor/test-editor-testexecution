package org.testeditor.web.backend.testexecution.distributed.manager

import com.google.common.cache.CacheBuilder
import com.google.common.cache.LoadingCache
import java.io.File
import java.util.List
import java.util.Map
import java.util.Optional
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
	
	var LoadingCache<TestExecutionKey, TestJobInfo> _jobCache = null
	var LoadingCache<TestExecutionKey, Optional<Map<String, Object>>> _callTreeMap = null
	
	// late initialization of caches; we must not access config object too early!
	private def jobCache() {
		if (_jobCache === null) {
			_jobCache = CacheBuilder.newBuilder.maximumSize(config.get.testJobCacheSize).<TestExecutionKey, TestJobInfo>build[key|
				callTreeMap.get(key)
				/* TODO capabilities need to be stored in call tree yaml! */
				.map[new TestJob(key, #{}, getOrDefault('resourcePaths',#[]) as List<String>)]
				.orElse(TestJob.NONE)
			]			
		}
		return _jobCache
	}
	
	private def callTreeMap() {
		if (_callTreeMap === null) {
			_callTreeMap = CacheBuilder.newBuilder.maximumSize(config.get.testJobCallTreeCacheSize).build[TestExecutionKey key|
				key.getLatestCallTree(workspace).map[readYaml]
			]
		}
		return _callTreeMap
	}

	
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