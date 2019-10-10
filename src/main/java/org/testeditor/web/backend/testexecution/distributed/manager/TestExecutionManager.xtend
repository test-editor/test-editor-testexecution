package org.testeditor.web.backend.testexecution.distributed.manager

import java.io.File
import java.time.Instant
import javax.inject.Inject
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestExecutorProvider
import org.testeditor.web.backend.testexecution.TestLogWriter
import org.testeditor.web.backend.testexecution.TestStatusMapper
import org.testeditor.web.backend.testexecution.distributed.common.TestJob
import org.testeditor.web.backend.testexecution.util.CallTreeYamlUtil

import static org.testeditor.web.backend.testexecution.TestExecutorProvider.CALL_TREE_YAML_FILE
import static org.testeditor.web.backend.testexecution.TestExecutorProvider.LOGFILE_ENV_KEY
import static org.testeditor.web.backend.testexecution.TestStatus.RUNNING

interface TestExecutionManager {

	def void cancelJob(TestExecutionKey key)

	def void addJob(TestJob job)

}

class LocalSingleWorkerExecutionManager implements TestExecutionManager {
	static val logger = LoggerFactory.getLogger(LocalSingleWorkerExecutionManager)

	@Inject TestExecutorProvider executorProvider
	@Inject TestStatusMapper statusMapper

	@Inject extension TestLogWriter
	@Inject extension CallTreeYamlUtil

	override cancelJob(TestExecutionKey key) {
		if (statusMapper.getStatus(key) === RUNNING) {
			statusMapper.terminateTestSuiteRun(key)
		}
	}

	override addJob(TestJob it) {
		val builder = executorProvider.testExecutionBuilder(id, resourcePaths, '') // commit id unknown
		val logFile = builder.environment.get(LOGFILE_ENV_KEY)
		val callTreeFileName = builder.environment.get(CALL_TREE_YAML_FILE)
		logger.info('''Starting test for resourcePaths='«resourcePaths.join(',')»' logging into logFile='«logFile»', callTreeFile='«callTreeFileName»'.''')
		val callTreeFile = new File(callTreeFileName)
		callTreeFile.writeCallTreeYamlPrefix(executorProvider.yamlFileHeader(id, Instant.now, resourcePaths))
		val testProcess = builder.start
		statusMapper.addTestSuiteRun(id, testProcess)[status|callTreeFile.writeCallTreeYamlSuffix(status)]
		testProcess.logToStandardOutAndIntoFile(new File(logFile))
	}

}
