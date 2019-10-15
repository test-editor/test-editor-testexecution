package org.testeditor.web.backend.testexecution

import java.util.Collection
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameters
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.mockito.Spy
import org.testeditor.web.backend.testexecution.util.serialization.JsonWriter
import org.testeditor.web.backend.testexecution.util.serialization.Json
import org.testeditor.web.backend.testexecution.util.serialization.YamlReader
import org.testeditor.web.backend.testexecution.util.serialization.Yaml
import org.mockito.InjectMocks
import org.mockito.MockitoAnnotations

@RunWith(Parameterized)
class TestExecutionCallTreeIllegalTest {
	
	@Spy JsonWriter jsonWriter = new Json
	@Spy YamlReader yamlReader = new Yaml
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
			#['1-2', null, '1-2-0-ID7'],
			// yaml has not the expected structure
			#['1-2', '''
				illegalFormedYaml:
				- "hello" : "ok"
			'''.toString, '1-2-0-ID7'],
			// yaml has not the expected structure
			#['1-2', '''
				testRuns:
				- "hello" : "ok"
			'''.toString, '1-2-0-ID7'],
			// node retrieval with wrong test execution key
			#['1-2', '''
				testRuns:
				- "testRunId": "0"
				  "children": 
				  - "id": "ID7"
			'''.toString, '1-3-0-ID7'],
			// node retrieval with wrong test execution key
			#['1-2', '''
				testRuns:
				- "testRunId": "0"
				  "children": 
				  - "id": "ID7"
			'''.toString, '1-2-0-ID8'],
			// node key incomplete (needs all four ids)
			#['1-2', '''
				testRuns:
				- "testRunId": "0"
				  "children":
				  - "id": "ID7"
			'''.toString, '1-2-0'],
			// node key incomplete (needs all four ids)
			#['1-2', '''
				testRuns:
				- "testRunId": "0"
				  "children":
				  - "id": "ID7"
			'''.toString, '1-2']
		]
	}

	var TestExecutionKey testSuiteRunKey
	var String yaml
	var TestExecutionKey nodeKey

	new(String testSuiteRunKey, String yaml, String nodeKey) {
		this.testSuiteRunKey = TestExecutionKey.valueOf(testSuiteRunKey)
		this.yaml = yaml
		this.nodeKey = TestExecutionKey.valueOf(nodeKey)
	}

	@Test(expected=IllegalArgumentException)
	def void test() {
		testExecutionCallTreeUnderTest.readString(this.testSuiteRunKey, this.yaml)

		testExecutionCallTreeUnderTest.getNodeJson(this.nodeKey)

	// expected exception		
	}

}
