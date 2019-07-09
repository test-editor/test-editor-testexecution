package org.testeditor.web.backend.testexecution

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.JacksonYAMLParseException
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import java.io.File
import org.junit.Test

import static org.assertj.core.api.Assertions.assertThat
import static org.junit.Assert.fail

/**
 * Test to document behavior of the YAML parser that used in TestSuiteResource when
 * the YAML file is malformed.
 */
class TestResultYamlParsingTest {

	// YAML file contains an error in line 169 due to a bug in TestProcess executing its onComplete action
	// before all child processes have been terminated, thus writing what should be a suffix somewhere in 
	// the middle of the file. 
	// See TestProcessTest::onCompleteIsCalledAfterChildProcessHasBeenFullyTerminated (regression test
	// corresponding to that bug)
	@Test
	def void parsingBrokenYAMLYieldsMarkedYAMLException() {
		// given
		val mapper = new ObjectMapper(new YAMLFactory)
		val cancelledTestTree = new File('src/test/resources/cancelledTestTree.yaml')

		// when
		try {
			mapper.readTree(cancelledTestTree)
			fail('Expected exception to be thrown')
			

		// then
		} catch (JacksonYAMLParseException exception) {
			assertThat(exception.message).contains('''
			while parsing a block mapping
			 in 'reader', line 1, column 1:
			    "started": "2019-05-22T11:22:53. ... 
			    ^
			expected <block end>, but found BlockMappingStart
			 in 'reader', line 169, column 11:
			              "exception": "java.net.ConnectEx ... 
			              ^
			''')
		}
	}

}
