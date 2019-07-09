package org.testeditor.web.backend.testexecution.loglines

import java.util.regex.Pattern

import static org.testeditor.web.backend.testexecution.loglines.LogLevel.*

class Log4JDefaultFilter implements LogFilter {

	static val log4jLevelNames = #{'FATAL' -> CRITICAL, 'ERROR' -> ERROR, 'WARN' -> WARNING, 'INFO' -> INFO, 'DEBUG' -> DEBUG, 'TRACE' -> TRACE}
	static val log4jPattern = Pattern.compile(
		'\\s+\\d{1,2}:\\d{1,2}:\\d{1,2}\\s+([A-Z]{4,5})\\s+\\[[^\\]]*\\]\\s+\\[TE-Test:\\s+[^\\]]+\\]\\s+[^\\s]+.*')

	override isVisibleOn(String logLine, LogLevel logLevel) {
		if (logLevel === TRACE) {
			return true
		} else {
			val matcher = log4jPattern.matcher(logLine)
			return matcher.find && log4jLevelNames.getOrDefault(matcher.group(1), TRACE) <= logLevel
		}
	}

}
