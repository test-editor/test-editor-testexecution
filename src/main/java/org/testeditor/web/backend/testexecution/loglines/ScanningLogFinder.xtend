package org.testeditor.web.backend.testexecution.loglines

import java.io.File
import java.util.regex.Pattern
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Provider
import org.apache.commons.lang3.Validate
import org.testeditor.web.backend.testexecution.common.LogLevel
import org.testeditor.web.backend.testexecution.common.TestExecutionConfiguration
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.util.HierarchicalLineSkipper

/**
 * Locates log files corresponding to test execution keys relying on file naming
 * conventions, and scans the files for lines marking the begin and end of
 * blocks belonging to specific call tree IDs.
 */
class ScanningLogFinder implements LogFinder {

	static val MARKER_REGEX = Pattern.compile('''@[A-Z_]+:(ENTER|LEAVE):(([0-9a-f]+:.+)|(\w+\.\w+\.\w+))''')
	static val ENTER_REGEX = Pattern.compile('''@[A-Z_]+:ENTER:([0-9a-f]+:)?(.+)''')
	static val ILLEGAL_TEST_EXECUTION_KEY_MESSAGE = "Provided test execution key must contain a test suite id and a test suite run id. (Key was: '%s'.)"

	@Inject @Named("workspace") Provider<File> workspaceProvider
	@Inject extension TestExecutionConfiguration
	@Inject extension HierarchicalLineSkipper
	@Inject extension LogFilter

	private def getLogLineSelector(TestExecutionKey key) {
		return if (key.caseRunId.nullOrEmpty) {
			new FullLogLineSelector(key, workspaceProvider.get)
		} else {
			val testCaseSelector = new PatternBasedLogLineSelector(key, workspaceProvider.get, //
			'''@TESTRUN:ENTER:«key.suiteId».«key.suiteRunId».«key.caseRunId»''', //
			'''@TESTRUN:LEAVE:«key.suiteId».«key.suiteRunId».«key.caseRunId»''')

			if (key.callTreeId.nullOrEmpty) {
				testCaseSelector
			} else {
				new PatternBasedLogLineSelector(key, workspaceProvider.get, //
				'''@[A-Z_]+:ENTER:[0-9a-f]+:«key.callTreeId»''', //
				'''@[A-Z_]+:LEAVE:[0-9a-f]+:«key.callTreeId»''', //
				testCaseSelector)
			}
		}
	}

	override getLogLinesForTestStep(TestExecutionKey key) {
		return getLogLinesForTestStep(key, LogLevel.TRACE)
	}

	override getLogLinesForTestStep(TestExecutionKey key, LogLevel logLevel) {
		Validate.notBlank(key?.suiteId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)
		Validate.notBlank(key?.suiteRunId, ILLEGAL_TEST_EXECUTION_KEY_MESSAGE, key?.toString)

		return key.logLineSelector.relevantLines.skipMarkerAndSubStepLines //
		.filter[it.isVisibleOn(logLevel)]
	}

	private def Iterable<String> skipMarkerAndSubStepLines(Iterable<String> lines) {
		return if (filterTestSubStepsFromLogs) {
			lines.skipChildren(ENTER_REGEX, [
				Pattern.compile('''@[A-Z_]+:LEAVE:([0-9a-f]+:)?«IF generic».+«ELSE»«matcher.group(2)»«ENDIF»''')
			])
		} else {
			lines.filter[!MARKER_REGEX.matcher(it).find]
		}
	}

}
