package org.testeditor.web.backend.testexecution.loglines

interface LogFilter {

	def boolean isVisibleOn(String logLine, LogLevel logLevel);

}
