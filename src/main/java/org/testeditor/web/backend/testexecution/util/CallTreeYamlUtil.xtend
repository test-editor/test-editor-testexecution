package org.testeditor.web.backend.testexecution.util

import java.io.File
import java.nio.file.Files
import java.time.Instant
import javax.inject.Singleton
import org.apache.commons.text.StringEscapeUtils
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus
import org.testeditor.web.backend.testexecution.distributed.common.TestJob

import static java.nio.charset.StandardCharsets.UTF_8
import static java.nio.file.StandardOpenOption.APPEND
import static java.nio.file.StandardOpenOption.CREATE
import static java.nio.file.StandardOpenOption.TRUNCATE_EXISTING

@Singleton
class CallTreeYamlUtil {
	def File writeCallTreeYamlPrefix(File callTreeYamlFile, String fileHeader) {
		callTreeYamlFile.parentFile.mkdirs
		Files.write(callTreeYamlFile.toPath, fileHeader.getBytes(UTF_8), CREATE, TRUNCATE_EXISTING)
		return callTreeYamlFile
	}
	
	def File writeCallTreeYamlPrefix(File callTreeYamlFile, TestExecutionKey executionKey, Instant instant, Iterable<String> resourcePaths) {
		writeCallTreeYamlPrefix(callTreeYamlFile, yamlFileHeader(executionKey, instant, resourcePaths))
	}
	
	def String yamlFileHeader(TestExecutionKey executionKey, Instant instant, Iterable<String> resourcePaths) {
		return '''
			"started": "«StringEscapeUtils.escapeJava(instant.toString)»"
			"testSuiteId": "«StringEscapeUtils.escapeJava(executionKey.suiteId)»"
			"testSuiteRunId": "«StringEscapeUtils.escapeJava(executionKey.suiteRunId)»"
			"resourcePaths": [ «resourcePaths.map['"'+StringEscapeUtils.escapeJava(it)+'"'].join(", ")» ]
			"testRuns":
		'''
	}

	def void writeCallTreeYamlSuffix(File callTreeYamlFile, TestStatus testStatus) {
		Files.write(callTreeYamlFile.toPath, #['''"status": "«testStatus»"'''], UTF_8, APPEND)
	}
}
