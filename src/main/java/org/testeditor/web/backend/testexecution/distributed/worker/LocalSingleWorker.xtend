package org.testeditor.web.backend.testexecution.distributed.worker

import java.io.File
import java.time.Instant
import java.util.Optional
import java.util.concurrent.CompletableFuture
import javax.inject.Inject
import javax.inject.Provider
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionCallTree
import org.testeditor.web.backend.testexecution.TestExecutorProvider
import org.testeditor.web.backend.testexecution.TestLogWriter
import org.testeditor.web.backend.testexecution.TestStatusMapper
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.TestJobInfo
import org.testeditor.web.backend.testexecution.distributed.common.Worker
import org.testeditor.web.backend.testexecution.util.CallTreeYamlUtil

import static org.testeditor.web.backend.testexecution.TestExecutorProvider.CALL_TREE_YAML_FILE
import static org.testeditor.web.backend.testexecution.TestExecutorProvider.LOGFILE_ENV_KEY

class LocalSingleWorker implements Worker {
	static val logger = LoggerFactory.getLogger(LocalSingleWorker)

	@Inject TestExecutionCallTree testExecutionCallTree
	@Inject extension TestStatusMapper statusMapper
	@Inject Provider<TestExecutorProvider> _executorProvider // eager initialization causes injection trouble due to Dropwizard env not being set
	@Inject extension TestLogWriter
	@Inject extension CallTreeYamlUtil
	
	var Optional<TestJobInfo> currentJob = Optional.empty
	
	private def TestExecutorProvider executorProvider() { _executorProvider.get }

	override startJob(TestJobInfo it) {
		currentJob = Optional.of(it)
		val builder = executorProvider.testExecutionBuilder(id, resourcePaths, '') // commit id unknown
		val logFile = builder.environment.get(LOGFILE_ENV_KEY)
		val callTreeFileName = builder.environment.get(CALL_TREE_YAML_FILE)
		logger.
			info('''Starting test for resourcePaths='«resourcePaths.join(',')»' logging into logFile='«logFile»', callTreeFile='«callTreeFileName»'.''')
		val callTreeFile = new File(callTreeFileName)
		callTreeFile.writeCallTreeYamlPrefix(executorProvider.yamlFileHeader(id, Instant.now, resourcePaths))
		val testProcess = builder.start
		statusMapper.addTestSuiteRun(id, testProcess)[status|callTreeFile.writeCallTreeYamlSuffix(status)]
		testProcess.logToStandardOutAndIntoFile(new File(logFile))
		
		return CompletableFuture.completedFuture(true)
	}

	override checkStatus() {
		currentJob.map[id.getStatus].orElse(TestStatus.IDLE)
	}

	override waitForStatus() {
		currentJob.map[id.waitForStatus].orElse(TestStatus.IDLE)
	}

	override kill() {
		currentJob.ifPresent[
			if (id.getStatus === TestStatus.RUNNING) {
				id.terminateTestSuiteRun
			}
		]
	}

	override getUri() {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}

	override getProvidedCapabilities() {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override getJsonCallTree(TestExecutionKey key) {
		val latestCallTree = executorProvider.getTestFiles(new TestExecutionKey(key.suiteId, key.suiteRunId)).filter[name.endsWith('.yaml')].sortBy[name].last
		testExecutionCallTree.readFile(key, latestCallTree)
		return testExecutionCallTree.getNodeJson(key)
	}
	
	override testJobExists(TestExecutionKey key) {
		currentJob.map[id.equals(key)].orElse(false)
	}

}
