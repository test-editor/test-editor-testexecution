package org.testeditor.web.backend.testexecution.screenshots

import java.io.File
import java.nio.file.Path
import java.nio.file.Paths
import java.util.regex.Pattern
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Provider
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static java.nio.charset.StandardCharsets.UTF_8

import static extension java.nio.file.Files.*

class TestArtifactRegistryScreenshotFinder implements ScreenshotFinder {

	@Inject @Named("workspace") Provider<File> workspace

	static val logger = LoggerFactory.getLogger(TestArtifactRegistryScreenshotFinder)

	static val BASE_PATH = ".testexecution/artifacts"
	static val FILE_EXTENSION = ".yaml"
	static val ENTRY_PATTERN = Pattern.compile('"screenshot": "([^"]*)"')

	override getScreenshotPathsForTestStep(TestExecutionKey key) {
		val filePath = artifactRegistryPath.resolve(key.toPath)

		return if (filePath.isReadable && filePath.isRegularFile) {
			filePath.readAllLines(UTF_8).map[entryPatternMatcher].filter[matches].map[group(1)]
		} else {
			logger.warn('File "{}" could not be read while trying to retrieve screenshots for test execution "{}".', filePath, key.toString)
			#[]
		}
	}

	override toPath(TestExecutionKey key) {
		return Paths.get(key.suiteId, key.suiteRunId, key.caseRunId, key.callTreeId + FILE_EXTENSION)
	}

	override toTestExecutionKey(Path path) {
		val pathElements = (if (path.isAbsolute) {
			artifactRegistryPath.relativize(path)
		} else {
			path
		}).map[toString].iterator

		return if (pathElements.hasNext) {
			var key = new TestExecutionKey(pathElements.next)
			if (pathElements.hasNext) {
				key = key.deriveWithSuiteRunId(pathElements.next)
				if (pathElements.hasNext) {
					key = key.deriveWithCaseRunId(pathElements.next)
					if (pathElements.hasNext) {
						val fileName = pathElements.next
						key = key.deriveWithCallTreeId(fileName.substring(0, fileName.length - FILE_EXTENSION.length))
					}
				}
				return key
			}
		} else {
			null
		}
	}

	private def Path getArtifactRegistryPath() {
		return workspace.get.absoluteFile.toPath.resolve(Paths.get(BASE_PATH))
	}

	private def entryPatternMatcher(String fileEntry) {
		return ENTRY_PATTERN.matcher(fileEntry)
	}

}
