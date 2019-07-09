package org.testeditor.web.backend.testexecution

import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.util.concurrent.Executor
import org.apache.commons.io.FileUtils
import org.apache.commons.io.IOUtils
import org.assertj.core.api.JUnitSoftAssertions
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Spy
import org.mockito.junit.MockitoJUnitRunner

import static java.nio.charset.StandardCharsets.UTF_8
import static org.mockito.Mockito.when

@RunWith(MockitoJUnitRunner)
class TestLogWriterTest {

	@InjectMocks TestLogWriter writerUnderTest
	@Spy MockExecutor executor
	@Mock Process mockProcess
	@Rule public TemporaryFolder logDirectory = new TemporaryFolder
	@Rule public JUnitSoftAssertions softly = new JUnitSoftAssertions
	val stdOutContent = new ByteArrayOutputStream

	val processOutput = '''
	First log line
	second log line
	third log line'''

	@Before
	def void given() {
		when(mockProcess.inputStream).thenReturn(
			IOUtils.toInputStream(processOutput, UTF_8)
		)
		System.setOut(new PrintStream(stdOutContent))
	}

	@After
	def void resetStdOut() {
		System.setOut(System.out)
	}

	@Test
	def void logsToBothFileAndStandardOut() {
		// given
		val logFile = logDirectory.newFile

		// when
		writerUnderTest.logToStandardOutAndIntoFile(mockProcess, logFile)
		executor.runNow

		// then
		val actualFileContent = FileUtils.readFileToString(logFile, UTF_8)
		val actualStdOutConent = stdOutContent.toString
		softly.assertThat(actualFileContent).isEqualTo(processOutput)
		softly.assertThat(actualStdOutConent).isEqualTo(processOutput)
	}

}

class MockExecutor implements Executor {

	var Runnable command

	override execute(Runnable command) {
		this.command = command
	}

	def void runNow() {
		command.run
	}

}
