package org.testeditor.web.backend.testexecution

import java.io.BufferedReader
import java.io.InputStreamReader

class ShellUtil {
	def String runShellCommand(String ... commands) {
		val processBuilder = new ProcessBuilder => [
			command(commands)
			redirectOutput
		]
		val process = processBuilder.start
		val processOutput = new StringBuilder
		var BufferedReader processOutputReader = null
		try {
			processOutputReader = new BufferedReader(new InputStreamReader(process.inputStream))
			var String readLine
			while ((readLine = processOutputReader.readLine) !== null) {
				processOutput.append(readLine + System.lineSeparator)
			}
			process.waitFor
		} finally {
			if (processOutputReader !== null) {
				processOutputReader.close
			}
		}

		return processOutput.toString.trim
	}
}