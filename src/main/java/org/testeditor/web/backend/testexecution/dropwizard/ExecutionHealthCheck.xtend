package org.testeditor.web.backend.testexecution.dropwizard

import com.codahale.metrics.health.HealthCheck
import java.io.File
import javax.inject.Inject
import org.apache.commons.io.FileUtils
import org.apache.commons.io.IOUtils

import static com.codahale.metrics.health.HealthCheck.Result.healthy
import static com.codahale.metrics.health.HealthCheck.Result.unhealthy
import static java.nio.charset.StandardCharsets.UTF_8
import static java.util.concurrent.TimeUnit.MILLISECONDS

/**
 * Checks whether the application can launch external processes
 */
class ExecutionHealthCheck extends HealthCheck {

	static val HEALTH_CHECK_SCRIPT = '.healthCheck.sh'
	static val HEALTH_CHECK_OUTPUT = 'Test Editor Persistence Backend: execution health check'
	static val HEALTH_CHECK_TIMEOUT_MILLIS = 5000

	@Inject
	ProcessBuilder processBuilder

	override protected check() throws Exception {
		var result = healthy
		val process = preparedProcessBuilder.start

		if (!process.waitFor(HEALTH_CHECK_TIMEOUT_MILLIS, MILLISECONDS)) {
			result = unhealthy('''Execution of external process ran into timeout («HEALTH_CHECK_TIMEOUT_MILLIS» ms).''')
		} else {
			val actualOutput = IOUtils.toString(process.inputStream, UTF_8)
			if (!(HEALTH_CHECK_OUTPUT + '\n').equals(actualOutput)) {
				result = unhealthy('''Execution of external process failed to produce the expected output.''')
			}
		}

		return result
	}

	private def getPreparedProcessBuilder() {
		if (processBuilder.command.isNullOrEmpty) {
			val healthCheckScriptFile = new File(HEALTH_CHECK_SCRIPT)

			FileUtils.writeStringToFile(healthCheckScriptFile, '''
				#!/bin/sh
				echo '«HEALTH_CHECK_OUTPUT»'
			''', UTF_8)

			healthCheckScriptFile.deleteOnExit
			healthCheckScriptFile.executable = true

			processBuilder.command(#['/bin/sh', '-c', healthCheckScriptFile.absolutePath])
		}

		return processBuilder
	}

}
