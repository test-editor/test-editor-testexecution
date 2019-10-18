package org.testeditor.web.backend.testexecution.common

import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonProperty
import java.io.File
import java.io.FileNotFoundException
import java.nio.file.FileSystems
import java.nio.file.Path
import java.util.Optional
import java.util.regex.Pattern
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.slf4j.LoggerFactory

import static extension java.nio.file.Files.list

@EqualsHashCode
@Data
class TestExecutionKey {
	static val logger = LoggerFactory.getLogger(TestExecutionKey)
	static val LOG_FOLDER = 'logs' // TODO replace w/ app config field!!

	static val PATTERN = Pattern.compile('([^-\\s]+)(-([^-\\s]*)(-([^-\\s]*)(-([^-\\s]*))?)?)?')
	
	val String suiteId
	val String suiteRunId
	val String caseRunId
	val String callTreeId

	new(String suiteId) {
		this(suiteId, "", "", "")
	}

	new(String suiteId, String suiteRunId) {
		this(suiteId, suiteRunId, "", "")
	}

	new(String suiteId, String suiteRunId, String caseRunId) {
		this(suiteId, suiteRunId, caseRunId, "")
	}

	@JsonCreator
	new(
		@JsonProperty('suiteId') String suiteId,
		@JsonProperty('suiteRunId') String suiteRunId,
		@JsonProperty('caseRunId') String caseRunId,
		@JsonProperty('callTreeId') String callTreeId
	) {
		this.suiteId = suiteId
		this.suiteRunId = suiteRunId
		this.caseRunId = caseRunId
		this.callTreeId = callTreeId
	}
	
	def boolean isDerivedOf(TestExecutionKey parent) {
		return (parent !== null)
			&& (this.suiteId == parent.suiteId)
			&& ((this.suiteRunId.nullOrEmpty && this.caseRunId.nullOrEmpty && this.callTreeId.nullOrEmpty) || this.suiteRunId == parent.suiteRunId)
			&& ((this.caseRunId.nullOrEmpty && this.callTreeId.nullOrEmpty) || this.caseRunId == parent.caseRunId)
			&& (this.callTreeId.nullOrEmpty || this.callTreeId == parent.callTreeId)
	}
	
	def TestExecutionKey deriveWithSuiteRunId() {
		return new TestExecutionKey(this.suiteId, this.suiteRunId, "", "")
	}
	
	def TestExecutionKey deriveWithSuiteRunId(String suiteRunId) {
		return new TestExecutionKey(this.suiteId, suiteRunId, "", "")
	}
	
	def TestExecutionKey deriveWithCaseRunId(String caseRunId) {
		if (this.suiteRunId.nullOrEmpty) {
			throw new IllegalStateException('cannot derive case run key of a key that has no suiteRunId specified')
		}
		return new TestExecutionKey(this.suiteId, this.suiteRunId, caseRunId, "")
	}
	
	def TestExecutionKey deriveWithCallTreeId(String callTreeId) {
		if (this.suiteRunId.nullOrEmpty || this.caseRunId.nullOrEmpty) {
			throw new IllegalStateException('cannot derive call tree key of a key that has no suiteRunId and caseRunId specified')
		}
		return new TestExecutionKey(this.suiteId, this.suiteRunId, this.caseRunId, callTreeId)
	}

	override toString() {
		return '''«this.suiteId»-«this.suiteRunId»-«this.caseRunId»-«this.callTreeId»'''
	}
	
	def static TestExecutionKey valueOf(String keyAsString) {
		if (keyAsString === null) {
			throw new IllegalArgumentException('key may not be NULL')
		}
		val matcher = PATTERN.matcher(keyAsString)
		val matched = matcher.matches
		if (!matched) {
			throw new IllegalArgumentException('''key = '«keyAsString»' does not match expected pattern = '«PATTERN.pattern»'. ''')
		}
		return new TestExecutionKey(matcher.group(1),
			matcher.group(3)?:"",
			matcher.group(5)?:"",
			matcher.group(7)?:"")
	}
	
	def Path getLogFile(File workspace) {
		val keyName = this.toString
		logger.debug('getting log file for test execution key "{}".', keyName)

		val matcher = FileSystems.^default.getPathMatcher('''glob:testrun.«this.suiteId»-«this.suiteRunId»--.*.log''')
		val logFile = workspace.toPath.resolve('logs').list //
		.filter[matcher.matches(fileName)] //
		.findFirst //
		.orElseThrow [
			new FileNotFoundException('''No log file for test execution key '«keyName»' found.''')
		]

		logger.debug('retrieved log file "{}" for test execution key "{}".', logFile.fileName, keyName)

		return logFile
	}
	
	def Iterable<File> getTestFiles(File workspace) {
		val testPath = workspace.toPath.resolve(LOG_FOLDER)
		val unfilteredtestFiles = testPath.toFile.listFiles
		val testFiles = unfilteredtestFiles?.filter[name.startsWith('''testrun.«this.toString».''')] ?: #[]
		return testFiles
	}
	
	def Optional<File> getLatestCallTree(File workspace) {
		return Optional.ofNullable(workspace.testFiles.filter[name.endsWith('.yaml')].sortBy[name].last)
	}
}
