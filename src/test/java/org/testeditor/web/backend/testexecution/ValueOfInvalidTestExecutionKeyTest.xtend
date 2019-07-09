package org.testeditor.web.backend.testexecution

import java.util.Collection
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameter
import org.junit.runners.Parameterized.Parameters
import org.testeditor.web.dropwizard.testing.AbstractTest

@RunWith(Parameterized)
class ValueOfInvalidTestExecutionKeyTest extends AbstractTest {

	@Parameters
	static def Collection<Object> data() {
		#[
			'-1-2-3-4',
			'1-2-3-4-',
			'-3-2-1',
			'3-2-1--',
			'-1-2',
			'1-2---',
			'-1',
			'1----',
			'-',
			'--',
			'---',
			'----',
			'-----',
			'1 1-2-3-4',
			'1-2 2-3-4',
			'1-2-3 3-4',
			'1-2-3-4 4',
			'1 -2-3-4',
			'1-2 -3-4',
			'1-2-3 -4',
			'1-2-3-4 ',
			' 1-2-3-4',
			'1- 2-3-4',
			'1-2- 3-4',
			'1-2-3- 4',
			null,
			''
		]
	}

	@Parameter
	public var String value

	@Test(expected = IllegalArgumentException)
	def void testValueOf() {
		// given + when
		TestExecutionKey.valueOf(value)

		// then
		// exception is expected
	}

}
