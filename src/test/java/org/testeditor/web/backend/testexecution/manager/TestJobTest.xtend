package org.testeditor.web.backend.testexecution.manager

import com.fasterxml.jackson.databind.ObjectMapper
import io.dropwizard.jackson.Jackson
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static io.dropwizard.testing.FixtureHelpers.*
import static org.assertj.core.api.Assertions.assertThat

class TestJobTest {

	static val ObjectMapper mapper = Jackson.newObjectMapper();

	@org.junit.Test
	def void testJobSerializesToJSON() throws Exception {
		// given
		val testJob = new TestJob() => [
			capabilities = #{ 'firefox', 'chrome' }
			id = new TestExecutionKey('suiteId', 'suiteRunId', 'testCaseId', 'callTreeId')
			resourcePaths = #[ 'path/to/test.tcl', 'another/differentTest.tcl' ]
			status = -1
		]
		val expected = mapper.writeValueAsString(mapper.readValue(fixture("json/testJob.json"), TestJob))

		// when
		val actual = mapper.writeValueAsString(testJob)

		// then
		assertThat(actual).isEqualTo(expected)
	}

	@org.junit.Test
	def void testJobDeserializesFromJSON() throws Exception {
		// given
		val testJob = new TestJob() => [
			capabilities = #{ 'firefox', 'chrome' }
			id = new TestExecutionKey('suiteId', 'suiteRunId', 'testCaseId', 'callTreeId')
			resourcePaths = #[ 'path/to/test.tcl', 'another/differentTest.tcl' ]
			status = -1
		]

		// when
		val actual = mapper.readValue(fixture("json/testJob.json"), TestJob)

		// then
		assertThat(actual).isEqualTo(testJob)
	}

}
