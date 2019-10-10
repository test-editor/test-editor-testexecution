package org.testeditor.web.backend.testexecution.distributed.manager

import com.fasterxml.jackson.databind.ObjectMapper
import io.dropwizard.jackson.Jackson
import org.junit.Test
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.distributed.common.TestJob

import static io.dropwizard.testing.FixtureHelpers.*
import static org.assertj.core.api.Assertions.assertThat

class TestJobTest {

	static val ObjectMapper mapper = Jackson.newObjectMapper();

	@Test
	def void testJobSerializesToJSON() throws Exception {
		// given
		val testJob = new TestJob(new TestExecutionKey('suiteId', 'suiteRunId', 'testCaseId', 'callTreeId'), #{'firefox', 'chrome'},
			#['path/to/test.tcl', 'another/differentTest.tcl'])
		val expected = mapper.writeValueAsString(mapper.readValue(fixture("json/testJob.json"), TestJob))

		// when
		val actual = mapper.writeValueAsString(testJob)

		// then
		assertThat(actual).isEqualTo(expected)
	}

	@Test
	def void testJobDeserializesFromJSON() throws Exception {
		// given
		val testJob = new TestJob(new TestExecutionKey('suiteId', 'suiteRunId', 'testCaseId', 'callTreeId'), #{'firefox', 'chrome'},
			#['path/to/test.tcl', 'another/differentTest.tcl'])

		// when
		val actual = mapper.readValue(fixture("json/testJob.json"), TestJob)

		// then
		assertThat(actual).isEqualTo(testJob)
	}

}