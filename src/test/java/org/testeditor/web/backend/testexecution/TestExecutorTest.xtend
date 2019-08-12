package org.testeditor.web.backend.testexecution

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.classic.spi.LoggingEvent
import ch.qos.logback.core.Appender
import java.io.File
import java.util.regex.Pattern
import javax.inject.Provider
import org.assertj.core.api.Condition
import org.junit.Assert
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Captor
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito
import org.mockito.junit.MockitoJUnitRunner
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionConfiguration

import static org.assertj.core.api.Assertions.*
import static org.mockito.Mockito.*

@RunWith(MockitoJUnitRunner)
class TestExecutorTest {

	@Rule public val temporaryFolder = new TemporaryFolder

	@InjectMocks TestExecutorProvider testExecutorProviderUnderTest

	@Mock Provider<File> workspaceProviderMock
	@Mock TestExecutionConfiguration config
	@Mock Appender<ILoggingEvent> logAppender
	@Captor ArgumentCaptor<LoggingEvent> logCaptor

	@Before
	def void setupWorkspaceProviderMock() {
		Mockito.when(workspaceProviderMock.get).thenReturn(temporaryFolder.root)
	}

	@Before
	def void setupLogging() {
		val logBackRootLogger = LoggerFactory.getLogger(Logger.ROOT_LOGGER_NAME) as Logger
		logBackRootLogger.addAppender(logAppender)
	}

	@Test
	def void testWrongFilenameFailsWithException() {
		// given
		val existingNonTestFile = 'README.md'
		temporaryFolder.newFile(existingNonTestFile)

		// when
		try {
			testExecutorProviderUnderTest.testExecutionBuilder(existingNonTestFile)
			Assert.fail('expected exception was NOT thrown!')
		} catch (IllegalArgumentException expectedException) {
			// then
			assertThat(expectedException.message).contains(''''«existingNonTestFile»' is no test case'''.toString)
			verify(logAppender).doAppend(logCaptor.capture)
			assertThat(logCaptor.value).satisfies [
				assertThat(formattedMessage).contains(''''«existingNonTestFile»' is no test case'''.toString)
				assertThat(level).isEqualTo(Level.ERROR)
			]
		}

	}

	@Test
	def void testNonExistingFileFailsWithException() {
		// given
		val nonExistingFile = 'FantasyTest.tcl'

		// when
		try {
			testExecutorProviderUnderTest.testExecutionBuilder(nonExistingFile)
			Assert.fail('expected exception was NOT thrown!')
		} catch (IllegalArgumentException expectedException) {
			// then
			assertThat(expectedException.message).isEqualTo('''File '«nonExistingFile»' does not exist'''.toString)
			verify(logAppender).doAppend(logCaptor.capture)
			assertThat(logCaptor.value).satisfies [
				assertThat(formattedMessage).isEqualTo('''File '«nonExistingFile»' does not exist'''.toString)
				assertThat(level).isEqualTo(Level.ERROR)
			]
		}
	}

	@Test
	def void testWithRegularTestFileCreatesWellFormedProcessBuilder() {
		// given
		val exampleTestFile = 'src/test/java/org/example/ExampleTest.tcl'
		temporaryFolder.newFolder(exampleTestFile.split('/').takeWhile[!endsWith('.tcl')])
		temporaryFolder.newFile(exampleTestFile)
		val expectedCommandMatchingRegEx = regExContainingInOrder('./gradlew', 'test', '--tests org.example.ExampleTest')
		val expectedLogFileMatchingRegEx = '\\Q' + TestExecutorProvider.LOG_FOLDER + '/testrun-org.example.ExampleTest-\\E[0-9]{17}\\.log'

		// when
		val processBuilder = testExecutorProviderUnderTest.testExecutionBuilder(exampleTestFile)

		// then
		assertThat(processBuilder).isNotNull
		verifyZeroInteractions(logAppender)

		processBuilder => [
			assertThat(command).haveAtLeastOne(stringMatching(expectedCommandMatchingRegEx, 'gradle command line with test class'))

			assertThat(environment).hasEntrySatisfying(TestExecutorProvider.LOGFILE_ENV_KEY,
				stringMatching(expectedLogFileMatchingRegEx, 'log file named accordingly'))

			assertThat(directory.absolutePath).isEqualTo(temporaryFolder.root.absolutePath)
		]
	}

	private def Condition<String> stringMatching(String regEx, String message) {
		return new Condition<String>([matches(regEx)], message)
	}

	private def String regExContainingInOrder(String ... unquotedSubstrings) {
		return unquotedSubstrings.map[Pattern.quote(it)].join('.*', '.*', '.*', [it])
	}

}
