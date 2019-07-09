package org.testeditor.web.backend.testexecution

import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executor
import javax.inject.Inject
import org.apache.commons.io.IOUtils
import org.apache.commons.io.output.TeeOutputStream

class TestLogWriter {

	@Inject Executor executor

	def void logToStandardOutAndIntoFile(Process process, File logFile) {
		logFile.parentFile.mkdirs

		val logStream = new FileOutputStream(logFile)
		val destination = new TeeOutputStream(System.out, logStream)

		CompletableFuture.runAsync( [
			try {
				IOUtils.copy(process.inputStream, destination)
			} finally {
				logStream?.close
			}
		], executor)
	}

}
