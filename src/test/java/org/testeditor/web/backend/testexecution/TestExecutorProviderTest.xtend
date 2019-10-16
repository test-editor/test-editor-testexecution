package org.testeditor.web.backend.testexecution

import java.time.Instant
import org.junit.Test
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.util.CallTreeYamlUtil

class TestExecutorProviderTest {

	val callTreeYamlUtil = new CallTreeYamlUtil

	@Test
	def void testYamlHeaderDoesEscaping() {
		// given
		val executionKey = TestExecutionKey.valueOf('some\'ones-key-realyµa"sty')
		val resourcePaths = #[
			"resouce/with/Slash/Verträge.tcl",
			'cool/pa\th/Muß-Ge"hen.tcl'
		]
		val now = Instant.now

		// when
		val result = callTreeYamlUtil.yamlFileHeader(executionKey, now, resourcePaths)

		// then
		result.equals('''
			"started": "«now.toString»"
			"testSuiteId": "some'ones"
			"testSuiteRunId": "realyµa\"sty"
			"resourcePaths": [ "resouce/with/Slash/Verträge.tcl", "cool/pa\th/Muß-Ge\"hen.tcl" ]
			"testRuns":
		'''.toString)
	}

}
