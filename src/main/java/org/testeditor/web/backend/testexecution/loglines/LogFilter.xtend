package org.testeditor.web.backend.testexecution.loglines

import org.testeditor.web.backend.testexecution.common.LogLevel

interface LogFilter {

	def boolean isVisibleOn(String logLine, LogLevel logLevel);

}
