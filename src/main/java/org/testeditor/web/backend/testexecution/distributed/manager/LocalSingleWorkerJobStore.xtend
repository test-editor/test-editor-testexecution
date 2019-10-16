package org.testeditor.web.backend.testexecution.distributed.manager

import com.google.common.cache.CacheBuilder
import javax.inject.Inject
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.distributed.common.WritableTestJobStore
import org.testeditor.web.backend.testexecution.util.serialization.YamlReader

class LocalSingleWorkerJobStore implements WritableTestJobStore {
	@Inject YamlReader yamlReader
	
	val jobCache = CacheBuilder.newBuilder.maximumSize(1000).build[TestExecutionKey key|
		
	]
	
	override testJobExists(TestExecutionKey key) {
		
	}
	
	override getJsonCallTree(TestExecutionKey key) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override store(TestExecutionKey key, TestJob job) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
}