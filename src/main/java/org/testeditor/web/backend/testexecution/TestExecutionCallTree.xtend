package org.testeditor.web.backend.testexecution

import java.util.ArrayList
import java.util.List
import java.util.Map
import javax.inject.Inject
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.util.serialization.JsonWriter

class TestExecutionCallTree {

	@Inject extension JsonWriter

	static val childrenKey = 'children'
	static val idKey = 'id'

	def String getCompleteTestCallTreeJson(TestExecutionKey executionKey, ()=>Map<String,Object> yamlObjectProvider) {
		val test = executionKey.testNode(yamlObjectProvider)
		if (test !== null) {
			return test.writeJson
		} else {
			throw new IllegalArgumentException('''test for passed executionKey = '«executionKey»' cannot be found.''')
		}
	}

	def String getNodeJson(TestExecutionKey executionKey, ()=>Map<String,Object> yamlObjectProvider) {
		val test = executionKey.testNode(yamlObjectProvider)
		val node = test.typedMapGetArray(childrenKey)?.findNode(executionKey.callTreeId)
		if (node !== null) {
			return node.writeToJsonHidingChildren
		} else {
			throw new IllegalArgumentException('''TestExecutionKey = '«executionKey»' cannot be found in call tree.''')
		}
	}

	def Iterable<TestExecutionKey> getDescendantsKeys(TestExecutionKey key, ()=>Map<String,Object> yamlObjectProvider) {
		val node = key.testNode(yamlObjectProvider).typedMapGetArray(childrenKey)?.findNode(key.callTreeId)
		return if (node !== null && !node.empty) {
			node.descendantsKeys(key)
		} else {
			#[]
		}
	}

	private def Iterable<TestExecutionKey> descendantsKeys(Map<String, Object> node, TestExecutionKey executionKey) {
		val keys = newLinkedList()
		if (node.get(childrenKey) !== null) {
			node.<Map<String, Object>>typedMapGetArray(childrenKey).forEach [
				keys += executionKey.deriveWithCallTreeId(get(idKey) as String)
				keys += descendantsKeys(executionKey)
			]
		}
		return keys
	}

	private def Map<String, Object> testNode(TestExecutionKey executionKey, ()=>Map<String,Object> yamlObjectProvider) {
		if (executionKey.caseRunId.nullOrEmpty) {
			throw new IllegalArgumentException('''passed executionKey = '«executionKey»' must provide a caseRunId.''')
		}

		val testRuns = yamlObjectProvider.apply.typedMapGetArray("testRuns").filter(Map)
		val test = testRuns.findFirst [ test |
			executionKey.caseRunId.equals(test.get("testRunId"))
		]

		if (test === null) {
			throw new IllegalArgumentException('''could not find test run with id = '«executionKey.caseRunId»' in testRuns = '«testRuns.join(', ')»' ''')
		} else {
			return test
		}
	}

	private def String writeToJsonHidingChildren(Map<String, Object> node) {
		val children = node.get(childrenKey)
		node.remove(childrenKey)
		val result = node.writeJson
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
				val recursivelyFoundNode = nodes.map[node|(node.get(childrenKey) as ArrayList<Map<String, Object>>)?.findNode(callTreeId)].filterNull.
					head
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
