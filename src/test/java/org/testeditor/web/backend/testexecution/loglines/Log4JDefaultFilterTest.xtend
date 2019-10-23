package org.testeditor.web.backend.testexecution.loglines

import java.util.Collection
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameters
import org.testeditor.web.backend.testexecution.common.LogLevel

import static org.assertj.core.api.Assertions.assertThat
import static org.testeditor.web.backend.testexecution.common.LogLevel.*

@RunWith(Parameterized)
@FinalFieldsConstructor
class Log4JDefaultFilterTest {

	val String logLine
	val LogLevel logLevel
	val boolean expectedResult

	static val logLines = #{
		CRITICAL -> '    23:42:00 FATAL [Test worker]  [TE-Test: TestName] ReportingClass Message part.',
		ERROR -> '    23:42:00 ERROR [Test worker]  [TE-Test: TestName] ReportingClass Message part.',
		WARNING -> '    23:42:00 WARN  [Test worker]  [TE-Test: TestName] ReportingClass Message part.',
		INFO -> '    23:42:00 INFO  [Test worker]  [TE-Test: TestName] ReportingClass Message part.',
		DEBUG -> '    23:42:00 DEBUG [Test worker]  [TE-Test: TestName] ReportingClass Message part.',
		TRACE -> '    23:42:00 TRACE [Test worker]  [TE-Test: TestName] ReportingClass Message part.'
	}
	static val unformattedLogLine = 'FATAL ERROR WARN INFO DEBUG TRACE unformatted log line'
	static val unknownLogLevelLine = '    23:42:00 WRONG [Test worker]  [TE-Test: TestName] Will match regex.'

	@Parameters(name='log line: "{0}"; log level: {1}; accept? {2}')
	def static Collection<Object[]> data() {
		return #[
			#[logLines.get(CRITICAL), CRITICAL, true],
			#[logLines.get(CRITICAL), ERROR, true],
			#[logLines.get(CRITICAL), WARNING, true],
			#[logLines.get(CRITICAL), INFO, true],
			#[logLines.get(CRITICAL), DEBUG, true],
			#[logLines.get(CRITICAL), TRACE, true],
			#[logLines.get(ERROR), CRITICAL, false],
			#[logLines.get(ERROR), ERROR, true],
			#[logLines.get(ERROR), WARNING, true],
			#[logLines.get(ERROR), INFO, true],
			#[logLines.get(ERROR), DEBUG, true],
			#[logLines.get(ERROR), TRACE, true],
			#[logLines.get(WARNING), CRITICAL, false],
			#[logLines.get(WARNING), ERROR, false],
			#[logLines.get(WARNING), WARNING, true],
			#[logLines.get(WARNING), INFO, true],
			#[logLines.get(WARNING), DEBUG, true],
			#[logLines.get(WARNING), TRACE, true],
			#[logLines.get(INFO), CRITICAL, false],
			#[logLines.get(INFO), ERROR, false],
			#[logLines.get(INFO), WARNING, false],
			#[logLines.get(INFO), INFO, true],
			#[logLines.get(INFO), DEBUG, true],
			#[logLines.get(INFO), TRACE, true],
			#[logLines.get(DEBUG), CRITICAL, false],
			#[logLines.get(DEBUG), ERROR, false],
			#[logLines.get(DEBUG), WARNING, false],
			#[logLines.get(DEBUG), INFO, false],
			#[logLines.get(DEBUG), DEBUG, true],
			#[logLines.get(DEBUG), TRACE, true],
			#[logLines.get(TRACE), CRITICAL, false],
			#[logLines.get(TRACE), ERROR, false],
			#[logLines.get(TRACE), WARNING, false],
			#[logLines.get(TRACE), INFO, false],
			#[logLines.get(TRACE), DEBUG, false],
			#[logLines.get(TRACE), TRACE, true],
			#[unformattedLogLine, CRITICAL, false],
			#[unformattedLogLine, ERROR, false],
			#[unformattedLogLine, WARNING, false],
			#[unformattedLogLine, INFO, false],
			#[unformattedLogLine, DEBUG, false],
			#[unformattedLogLine, TRACE, true],
			#[unknownLogLevelLine, CRITICAL, false],
			#[unknownLogLevelLine, ERROR, false],
			#[unknownLogLevelLine, WARNING, false],
			#[unknownLogLevelLine, INFO, false],
			#[unknownLogLevelLine, DEBUG, false],
			#[unknownLogLevelLine, TRACE, true]
		]
	}

	@Test
	def void shouldIncludeLogLinesOfHigherSeverity() {
		// given
		val filterUnderTest = new Log4JDefaultFilter

		// when
		val actualResult = filterUnderTest.isVisibleOn(logLine, logLevel)

		// then
		assertThat(actualResult).isEqualTo(expectedResult)
	}

}
