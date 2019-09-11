package org.testeditor.web.backend.testexecution.worker

import java.io.File
import java.io.IOException
import java.io.OutputStream
import javax.ws.rs.WebApplicationException
import javax.ws.rs.core.StreamingOutput
import org.apache.commons.io.IOUtils
import org.apache.commons.io.input.Tailer
import org.apache.commons.io.input.TailerListenerAdapter

import static java.nio.charset.StandardCharsets.UTF_8
import java.io.PrintWriter

class LogTail2Stream extends TailerListenerAdapter implements StreamingOutput {

	val Tailer tailer
	volatile boolean active
	volatile boolean stopped
	var PrintWriter writer

	new(File fileToTail) {
		stopped = false
		active = false
		tailer = new Tailer(fileToTail, this)
	}

	override write(OutputStream output) throws IOException, WebApplicationException {
		active = true
		writer = new PrintWriter(output, true, UTF_8)
		tailer.run() // intentionally calling synchronously
	}

	def void stop() {
		if (active) {
			tailer.stop
		}
		stopped = true
	}

	override handle(String line) {
		writer.println(line)
	}

	override endOfFileReached() {
		if (stopped) {
			tailer.stop
		}
	}

}
