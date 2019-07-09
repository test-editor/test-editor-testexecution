package org.testeditor.web.backend.testexecution.loglines

import java.io.File
import java.util.regex.Pattern
import java.util.stream.Collectors
import java.util.stream.Stream
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static java.nio.charset.StandardCharsets.UTF_8

import static extension java.nio.file.Files.lines

@FinalFieldsConstructor
abstract class LogLineSelector {

	protected val TestExecutionKey key
	protected val File workspace

	final def String[] getRelevantLines() {
		return key.getLogFile(workspace).lines(UTF_8).findStart.findEnd.collect(Collectors.toList)
	}

	protected abstract def Stream<String> findStart(Stream<String> lines)

	protected abstract def Stream<String> findEnd(Stream<String> lines)

}

@FinalFieldsConstructor
class FullLogLineSelector extends LogLineSelector {

	/** default behavior does not limit the start */
	protected override Stream<String> findStart(Stream<String> lines) { return lines }

	/** default behavior does not limit the end */
	protected override Stream<String> findEnd(Stream<String> lines) { return lines }

}

class PatternBasedLogLineSelector extends LogLineSelector {

	val Pattern compiledEnterPattern
	val Pattern compiledLeavePattern
	val LogLineSelector preSelector

	new(TestExecutionKey key, File workspace, String enterPattern, String leavePattern) {
		this(key, workspace, enterPattern, leavePattern, new FullLogLineSelector(key, workspace))
	}

	new(TestExecutionKey key, File workspace, String enterPattern, String leavePattern, LogLineSelector preSelector) {
		super(key, workspace)
		this.compiledEnterPattern = Pattern.compile(enterPattern)
		this.compiledLeavePattern = Pattern.compile(leavePattern)
		this.preSelector = preSelector
	}

	override protected findStart(Stream<String> lines) {
		return this.preSelector.findStart(lines).dropWhile[!compiledEnterPattern.matcher(it).find].skip(1)
	}

	override protected findEnd(Stream<String> lines) {
		return lines.takeWhile[!compiledLeavePattern.matcher(it).find]
	}

}
