package org.testeditor.web.backend.testexecution.worker

import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.io.PrintWriter
import javax.ws.rs.WebApplicationException
import javax.ws.rs.core.StreamingOutput
import org.apache.commons.io.input.Tailer
import org.apache.commons.io.input.TailerListenerAdapter
import org.slf4j.LoggerFactory

import static java.nio.charset.StandardCharsets.UTF_8

class LogTail2Stream extends TailerListenerAdapter implements StreamingOutput {
	static val logger = LoggerFactory.getLogger(LogTail2Stream)

	val Tailer tailer
	volatile boolean active
	volatile boolean stopped
	var PrintWriter writer

	new(File fileToTail) {
		logger.info('''tailing file "«fileToTail.absolutePath»"''')
		stopped = false
		active = false
		tailer = new Tailer(fileToTail, this)
	}

	override write(OutputStream output) throws IOException, WebApplicationException {
		active = true
		logger.info('''tailer for file "«tailer.file»" is active''')
		writer = new PrintWriter(output, true, UTF_8)
		tailer.run() // intentionally calling synchronously
	}

	def void stop() {
		logger.info('''stopping tailer for file "«tailer.file»"''')
		if (active) {
			tailer.stop
		}
		stopped = true
	}

	override handle(String line) {
		writer.println(line)
	}

	override endOfFileReached() {
		logger.info('''tailer has reached end of file "«tailer.file»"''')
		if (stopped) {
			tailer.stop
		}
	}

}
