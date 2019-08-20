package org.testeditor.web.backend.testexecution.manager

import com.squarespace.jersey2.guice.JerseyGuiceUtils
import org.junit.Before
import org.junit.BeforeClass

abstract class AbstractResourceTest<SUT> {

	abstract def SUT getSystemUnderTest()

	/**
	 * Base URL of the resource under test.
	 * The URL's last character must be a forward slash!
	 */
	abstract def String getBaseUrl()

	protected SUT systemUnderTest

	@BeforeClass
	static def void fixHK2GuiceProblem() {
		// see https://stackoverflow.com/questions/43452609/no-servicelocatorgenerator-installed-error-while-running-tests-in-dropwizard
		JerseyGuiceUtils.reset
	}

	@Before
	def void setup() {
		systemUnderTest = getSystemUnderTest
	}

}
