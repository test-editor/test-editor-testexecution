package org.testeditor.web.backend.testexecution.screenshots

import java.nio.file.Path
import org.testeditor.web.backend.testexecution.TestExecutionKey

interface ScreenshotFinder {

	def Iterable<String> getScreenshotPathsForTestStep(TestExecutionKey key)
	def Path toPath(TestExecutionKey key)
	def TestExecutionKey toTestExecutionKey(Path path)
}
