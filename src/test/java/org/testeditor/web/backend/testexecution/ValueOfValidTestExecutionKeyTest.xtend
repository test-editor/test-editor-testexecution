package org.testeditor.web.backend.testexecution

import java.util.Collection
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameter
import org.junit.runners.Parameterized.Parameters
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.dropwizard.testing.AbstractTest

@RunWith(Parameterized)
class ValueOfValidTestExecutionKeyTest extends AbstractTest {

	@Parameters
	static def Collection<Object[]> data() {
		#[
			#['1-2-3-4', #['1', '2', '3', '4']],
			#['3-2-1', #['3', '2', '1', '']],
			#['3-2-1-', #['3', '2', '1', '']],
			#['8-7', #['8', '7', '', '']],
			#['8-7-', #['8', '7', '', '']],
			#['8-7--', #['8', '7', '', '']],
			#['92', #['92', '', '', '']],
			#['92-', #['92', '', '', '']],
			#['92--', #['92', '', '', '']],
			#['92---', #['92', '', '', '']],
			#['H-E-L-O', #['H', 'E', 'L', 'O']],
			#['OO-LL-EH', #['OO', 'LL', 'EH', '']],
			#['COULD-BE', #['COULD', 'BE', '', '']],
			#['Samplix[]', #['Samplix[]', '', '', '']]
		]
	}

	@Parameter
	public var String value
	@Parameter(1)
	public var Iterable<String> result

	@Test
	def void testValueOf() {
		// given + when
		val testExecutionKey = TestExecutionKey.valueOf(value)

		// then
		testExecutionKey => [
			suiteId.assertEquals(result.get(0))
			suiteRunId.assertEquals(result.get(1))
			caseRunId.assertEquals(result.get(2))
			callTreeId.assertEquals(result.get(3))
		]
	}

}
