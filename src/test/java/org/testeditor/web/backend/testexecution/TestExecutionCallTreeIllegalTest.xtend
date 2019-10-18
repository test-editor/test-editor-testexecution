package org.testeditor.web.backend.testexecution

import java.util.Collection
import java.util.Map
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameters
import org.mockito.InjectMocks
import org.mockito.MockitoAnnotations
import org.mockito.Spy
import org.testeditor.web.backend.testexecution.calltrees.TestExecutionCallTree
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.util.serialization.Json
import org.testeditor.web.backend.testexecution.util.serialization.JsonWriter
import org.testeditor.web.backend.testexecution.util.serialization.Yaml
import org.testeditor.web.backend.testexecution.util.serialization.YamlReader

@RunWith(Parameterized)
class TestExecutionCallTreeIllegalTest {
	
	val extension YamlReader = new Yaml
	
	@Spy JsonWriter jsonWriter = new Json
	@InjectMocks
	var testExecutionCallTreeUnderTest = new TestExecutionCallTree // needs to be initialized otherwise test invocation fails!

	@Before
	def void initWithNewInstance() {
		MockitoAnnotations.initMocks(this)
	}

	@Parameters
	def static Collection<Object[]> data() {
		return #[
			// null yaml
			#[null, '1-2-0-ID7'],
			// yaml has not the expected structure
			#['''
				illegalFormedYaml:
				- "hello" : "ok"
			'''.toString, '1-2-0-ID7'],
			// yaml has not the expected structure
			#['''
				testRuns:
				- "hello" : "ok"
			'''.toString, '1-2-0-ID7'],
			// node retrieval with wrong test execution key
			#['''
				testRuns:
				- "testRunId": "0"
				  "children": 
				  - "id": "ID7"
			'''.toString, '1-2-0-ID8'],
			// node key incomplete (needs all four ids)
			#['''
				testRuns:
				- "testRunId": "0"
				  "children":
				  - "id": "ID7"
			'''.toString, '1-2-0'],
			// node key incomplete (needs all four ids)
			#['''
				testRuns:
				- "testRunId": "0"
				  "children":
				  - "id": "ID7"
			'''.toString, '1-2']
		]
	}

	var ()=>Map<String, Object> yamlProvider
	var TestExecutionKey nodeKey

	new(String yaml, String nodeKey) {
		this.yamlProvider = if (yaml === null) {
			[null]
		} else {
			[yaml.readYaml]
		}
		this.nodeKey = TestExecutionKey.valueOf(nodeKey)
	}

	@Test(expected=IllegalArgumentException)
	def void test() {
		testExecutionCallTreeUnderTest.getNodeJson(this.nodeKey, yamlProvider)

	// expected exception		
	}

}
