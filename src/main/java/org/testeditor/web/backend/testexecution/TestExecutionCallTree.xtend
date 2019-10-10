package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import java.io.File
import java.util.ArrayList
import java.util.List
import java.util.Map
import org.testeditor.web.backend.testexecution.common.TestExecutionKey

class TestExecutionCallTree {

	static val objectMapper = new ObjectMapper(new YAMLFactory)
	static val childrenKey = 'children'
	static val idKey = 'id'

	var TestExecutionKey executionKey
	var Map<String, Object> yamlObject

	def void readFile(TestExecutionKey executionKey, File yaml) {
		yamlObject = objectMapper.readValue(yaml, Map)
		this.executionKey = executionKey
	}

	def void readString(TestExecutionKey executionKey, String yaml) {
		if (yaml.nullOrEmpty) {
			throw new IllegalArgumentException('Yaml string must not be null nor empty')
		} else {
			yamlObject = objectMapper.readValue(yaml, Map)
			this.executionKey = executionKey
		}
	}

	def String getCompleteTestCallTreeJson(TestExecutionKey executionKey) {
		val test = executionKey.testNode
		if (test !== null) {
			val objectWriter = new ObjectMapper().writer
			return objectWriter.writeValueAsString(test)
		} else {
			throw new IllegalArgumentException('''test for passed executionKey = '«executionKey»' cannot be found.''')
		}
	}

	def String getNodeJson(TestExecutionKey executionKey) {
		val test = executionKey.testNode
		val node = test.typedMapGetArray(childrenKey)?.findNode(executionKey.callTreeId)
		if (node !== null) {
			return node.writeToJsonHidingChildren
		} else {
			throw new IllegalArgumentException('''TestExecutionKey = '«executionKey»' cannot be found in call tree.''')
		}
	}
	
	def Iterable<TestExecutionKey> getDescendantsKeys(TestExecutionKey key) {
		val node = key.testNode.typedMapGetArray(childrenKey)?.findNode(key.callTreeId)
		return if (node !== null && !node.empty) {
			node.descendantsKeys
		} else {
			#[]
		}
	}
	
	private def Iterable<TestExecutionKey> getDescendantsKeys(Map<String, Object> node) {
		val keys = newLinkedList()
		if (node.get(childrenKey) !== null) {
			node.<Map<String, Object>>typedMapGetArray(childrenKey).forEach[
				keys += executionKey.deriveWithCallTreeId(get(idKey) as String)
				keys += descendantsKeys
			]
		}
		return keys
	}

	private def Map<String, Object> getTestNode(TestExecutionKey executionKey) {
		if (!(this.executionKey.suiteId.equals(executionKey.suiteId) && this.executionKey.suiteRunId.equals(executionKey.suiteRunId))) {
			throw new IllegalArgumentException('''passed executionKey = '«executionKey»' does match test run execution key = '«this.executionKey»' ''')
		} else if (executionKey.caseRunId.nullOrEmpty) {
			throw new IllegalArgumentException('''passed executionKey = '«executionKey»' must provide a caseRunId.''')
		}

		val testRuns = yamlObject.typedMapGetArray("testRuns").filter(Map)
		val test = testRuns.findFirst [ test |
			executionKey.caseRunId.equals(test.get("testRunId"))
		]
		
		if (test===null) {
			throw new IllegalArgumentException('''could not find test run with id = '«executionKey.caseRunId»' in testRuns = '«testRuns.join(', ')»' ''')
		} else {
			return test
		}
	}

	private def String writeToJsonHidingChildren(Map<String, Object> node) {
		val children = node.get(childrenKey)
		node.remove(childrenKey)
		val objectWriter = new ObjectMapper().writer
		val result = objectWriter.writeValueAsString(node)
		node.put(childrenKey, children)

		return result
	}

	private def Map<String, Object> findNode(Iterable<Map<String, Object>> nodes, String callTreeId) {
		if (nodes === null) {
			return null
		} else {
			val nodeFound = nodes.findFirst[node|callTreeId.equals(node.get("id"))]
			if (nodeFound !== null) {
				return nodeFound
			} else {
				val recursivelyFoundNode = nodes.map[node|(node.get(childrenKey) as ArrayList<Map<String, Object>>)?.findNode(callTreeId)].filterNull.head
				return recursivelyFoundNode
			}
		}
	}

	private def <T> Iterable<T> typedMapGetArray(Object object, String key) {
		if (object instanceof Map) {
			val result = object.get(key)
			if ((result !== null) && (result instanceof List)) {
				return result as List<T>
			} else {
				throw new IllegalArgumentException('''expected array but got '«result»'.''')
			}
		} else {
			throw new IllegalArgumentException('''expected map with key = '«key»', got object = '«object»'.''')
		}
	}

}
