package org.testeditor.web.backend.testexecution.screenshots

import java.io.File
import javax.inject.Provider
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.testexecution.TestExecutionKey

import static java.nio.charset.StandardCharsets.UTF_8
import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.Mockito.when

import static extension java.nio.file.Files.write

@RunWith(MockitoJUnitRunner)
class TestArtifactRegistryScreenshotFinderTest {

	@Rule public val TemporaryFolder testRoot = new TemporaryFolder

	@Mock Provider<File> mockWorkspace

	@InjectMocks
	TestArtifactRegistryScreenshotFinder screenshotFinder

	@Test
	def void shouldReturnPathToScreenshot() {
		// given
		val key = new TestExecutionKey('0', '1', '2', '3')
		val expectedScreenshotPath = 'screenshots/test4711/weird_name_for_a_screenshot.png'

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val testCasePath = testRoot.newFolder('.testexecution', 'artifacts', '0', '1', '2').toPath
		val artifactRegistryFile = testCasePath.resolve('3.yaml')
		artifactRegistryFile.write(#['''"screenshot": "«expectedScreenshotPath»"'''], UTF_8)

		// when
		val actualScreenshotPaths = screenshotFinder.getScreenshotPathsForTestStep(key)

		// then
		assertThat(actualScreenshotPaths).containsOnly(expectedScreenshotPath)
	}

	@Test
	def void shouldreturnPathsToAllScreenshots() {
		// given
		val key = new TestExecutionKey('0', '1', '2', '3')
		val expectedScreenshotPaths = #[
			'screenshots/test4711/weird_name_for_a_screenshot.png',
			'screenshots/thats_right/ThereIsAnotherScreenshot.png',
			'screenshots/and/even/a-3rd-one.png'
		]

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val testCasePath = testRoot.newFolder('.testexecution', 'artifacts', '0', '1', '2').toPath
		val artifactRegistryFile = testCasePath.resolve('3.yaml')
		artifactRegistryFile.write(expectedScreenshotPaths.map['''"screenshot": "«it»"'''], UTF_8)

		// when
		val actualScreenshotPaths = screenshotFinder.getScreenshotPathsForTestStep(key)

		// then
		assertThat(actualScreenshotPaths).containsExactlyInAnyOrder(expectedScreenshotPaths)
	}

	@Test
	def void shouldReturnOnlyPathsToScreenshots() {
		// given
		val key = new TestExecutionKey('0', '1', '2', '3')
		val expectedScreenshotPaths = #[
			'screenshots/test4711/weird_name_for_a_screenshot.png',
			'screenshots/and/even/a-3rd-one.png'
		]

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val testCasePath = testRoot.newFolder('.testexecution', 'artifacts', '0', '1', '2').toPath
		val artifactRegistryFile = testCasePath.resolve('3.yaml')
		artifactRegistryFile.write(#[
			'''"screenshot": "«expectedScreenshotPaths.get(0)»"''', '''"screencast": "movies/are-not-screenshots.mov"''', '''"screenshot": "«expectedScreenshotPaths.get(1)»"'''],
			UTF_8)

		// when
		val actualScreenshotPaths = screenshotFinder.getScreenshotPathsForTestStep(key)

		// then
		assertThat(actualScreenshotPaths).containsExactlyInAnyOrder(expectedScreenshotPaths)
	}

	@Test
	def void shouldReturnEmptyListIfNoArtifactRegistryFileExists() {
		// given
		val key = new TestExecutionKey('0', '1', '2', '3')

		when(mockWorkspace.get).thenReturn(testRoot.root)

		// when
		val actualScreenshotPaths = screenshotFinder.getScreenshotPathsForTestStep(key)

		// then
		assertThat(actualScreenshotPaths).isEmpty
	}

}
