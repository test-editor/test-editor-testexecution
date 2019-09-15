package org.testeditor.web.backend.testexecution.worker

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.inject.Provider
import org.apache.commons.io.IOUtils
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.rules.TemporaryFolder
import org.mockito.ArgumentCaptor
import org.mockito.Mock
import org.mockito.Mockito
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestUtils.AfterRule
import org.testeditor.web.backend.testexecution.TestUtils.BeforeRule
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration
import org.testeditor.web.backend.testexecution.screenshots.ScreenshotFinder

import static java.nio.charset.StandardCharsets.UTF_8
import static java.nio.file.StandardOpenOption.APPEND
import static java.nio.file.StandardOpenOption.CREATE
import static java.nio.file.StandardOpenOption.WRITE
import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.verify
import static org.mockito.Mockito.when

import static extension java.nio.file.Files.createFile
import static extension java.nio.file.Files.write
import static extension org.mockito.MockitoAnnotations.initMocks

class TestResultWatcherTest {

	val workspace = new TemporaryFolder

	@Rule public val RuleChain rules = RuleChain.outerRule(workspace).around(new BeforeRule[setupMocks]).around(new AfterRule[tearDownExecutor])

	@Mock Provider<File> workspaceProviderMock

	@Mock TestExecutionManagerClient managerClientMock

	@Mock TestExecutionDropwizardConfiguration configMock

	@Mock ScreenshotFinder screenshotFinderMock

	var ExecutorService executor

	static val workerUrl = new URL('http://worker.example.com:4711')

	def TestResultWatcher getTestResultWatcher() {
		return new TestResultWatcher(workspaceProviderMock, managerClientMock, executor, screenshotFinderMock, configMock)
	}

	def void setupMocks() {
		this.initMocks
		when(workspaceProviderMock.get).thenReturn(workspace.root)
		when(configMock.workerUrl).thenReturn(workerUrl)
		when(configMock.useLogTailing).thenReturn(true)
		executor = Executors.newSingleThreadExecutor()
	}

	def void tearDownExecutor() {
		executor.shutdownNow
		executor.awaitTermination(5, TimeUnit.SECONDS)
		assertThat(executor.isTerminated).isTrue
	}

	@Test
	def void startsUploadWhenNewFileIsDetected() {
		// given
		val jobId = new TestExecutionKey('jobId')
		testResultWatcher.watch(jobId)
		val logFile = new File(workspace.newFolder('logs'), '''testrun.«jobId.toString».1912-06-23.log''').toPath

		// when
		logFile.createFile

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(jobId), eq(workspace.root.toPath.relativize(logFile).toString), any(LogTail2Stream))
	}

	@Test
	def void usesWorkerUrlFromConfig() {
		// given
		configMock = mock(TestExecutionDropwizardConfiguration)
		val configuredWorkerUrl = new URL('http://worker.example.com:4242/testWorker')
		when(configMock.workerUrl).thenReturn(configuredWorkerUrl)
		when(configMock.useLogTailing).thenReturn(true)
		val watcher = new TestResultWatcher(workspaceProviderMock, managerClientMock, executor, screenshotFinderMock, configMock)

		val jobId = new TestExecutionKey('jobId')
		watcher.watch(jobId)
		val logFile = new File(workspace.newFolder('logs'), '''testrun.«jobId.toString».1912-06-23.log''').toPath

		// when
		logFile.createFile

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		verify(managerClientMock).upload(eq(configuredWorkerUrl.toString), eq(jobId), eq(workspace.root.toPath.relativize(logFile).toString),
			any(LogTail2Stream))
	}

	@Test
	def void ignoresNewFilesWithoutAJobToWatch() {
		// given
		val jobId = new TestExecutionKey('jobId')
		val logFile = new File(workspace.newFolder('logs'), '''testrun.«jobId.toString».1912-06-23.log''').toPath

		// when
		logFile.createFile

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		Mockito.verifyZeroInteractions(managerClientMock)
	}

	@Test
	def void ignoresNewFilesThatDoNotMatchTheNamingPattern() {
		// given
		val jobId = new TestExecutionKey('jobId')
		testResultWatcher.watch(jobId)
		val otherJobId = new TestExecutionKey('otherJobId')
		val logFile = new File(workspace.newFolder('logs'), '''testrun.«otherJobId.toString».1912-06-23.log''').toPath

		// when
		logFile.createFile

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		Mockito.verifyZeroInteractions(managerClientMock)
	}

	@Test
	def void detectsWhenMultipleFilesAreAdded() {
		// given
		val jobId = new TestExecutionKey('jobId')
		testResultWatcher.watch(jobId)
		val logDir = workspace.newFolder('logs')
		val logFile = new File(logDir, '''testrun.«jobId.toString».1912-06-23.log''').toPath
		val yamlFile = new File(logDir, '''testrun.«jobId.toString».1912-06-23.yaml''').toPath

		// when
		logFile.createFile
		yamlFile.createFile

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(jobId), eq(workspace.root.toPath.relativize(logFile).toString), any(LogTail2Stream))
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(jobId), eq(workspace.root.toPath.relativize(yamlFile).toString), any(LogTail2Stream))
	}

	@Test
	def void detectsFilesFromTestArtifactRegistry() {
		// given
		val baseId = new TestExecutionKey('suiteId', 'suiteRunId')
		val fullId = baseId.deriveWithCaseRunId('caseRunId').deriveWithCallTreeId('callTreeId')
		testResultWatcher.watch(baseId)
		val screenshotsDir = workspace.newFolder('screenshots')
		val firstScreenshotFile = new File(screenshotsDir, 'firstScreenshot.png').toPath.createFile
		val secondScreenshotFile = new File(screenshotsDir, 'secondScreenshot.png').toPath.createFile

		val testArtifactDir = new File(workspace.newFolder('.testexecution'), 'artifacts')
		val suiteDir = new File(testArtifactDir, fullId.suiteId)
		val suiteRunDir = new File(suiteDir, fullId.suiteRunId)
		val testRunDir = new File(suiteRunDir, fullId.caseRunId)
		val callTreeNodeArtifactFile = new File(testRunDir, fullId.callTreeId + '.yaml').toPath
		testRunDir.mkdirs

		when(screenshotFinderMock.toTestExecutionKey(eq(suiteRunDir.toPath))).thenReturn(baseId)
		when(screenshotFinderMock.toTestExecutionKey(eq(callTreeNodeArtifactFile))).thenReturn(fullId)
		when(screenshotFinderMock.getScreenshotPathsForTestStep(eq(fullId))).thenReturn(
			#['screenshots/firstScreenshot.png', 'screenshots/secondScreenshot.png'])

		// when
		callTreeNodeArtifactFile.write(#[
			'"screenshot": "screenshots/firstScreenshot.png"',
			'"screenshot": "screenshots/secondScreenshot.png"'
		], UTF_8, WRITE, APPEND, CREATE)
		assertThat(callTreeNodeArtifactFile).exists

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(fullId), eq(workspace.root.toPath.relativize(firstScreenshotFile).toString),
			any(InputStream))
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(fullId), eq(workspace.root.toPath.relativize(secondScreenshotFile).toString),
			any(InputStream))
	}

	@Test
	def void uploadsArtifactRegistryFiles() {
		// given
		val baseId = new TestExecutionKey('suiteId', 'suiteRunId')
		val fullId = baseId.deriveWithCaseRunId('caseRunId').deriveWithCallTreeId('callTreeId')
		testResultWatcher.watch(baseId)
		val screenshotsDir = workspace.newFolder('screenshots')
		new File(screenshotsDir, 'firstScreenshot.png').toPath.createFile
		new File(screenshotsDir, 'secondScreenshot.png').toPath.createFile

		val testArtifactDir = new File(workspace.newFolder('.testexecution'), 'artifacts')
		val suiteDir = new File(testArtifactDir, fullId.suiteId)
		val suiteRunDir = new File(suiteDir, fullId.suiteRunId)
		val testRunDir = new File(suiteRunDir, fullId.caseRunId)
		val callTreeNodeArtifactFile = new File(testRunDir, fullId.callTreeId + '.yaml').toPath
		testRunDir.mkdirs

		when(screenshotFinderMock.toTestExecutionKey(eq(suiteRunDir.toPath))).thenReturn(baseId)
		when(screenshotFinderMock.toTestExecutionKey(eq(callTreeNodeArtifactFile))).thenReturn(fullId)
		when(screenshotFinderMock.getScreenshotPathsForTestStep(eq(fullId))).thenReturn(
			#['screenshots/firstScreenshot.png', 'screenshots/secondScreenshot.png'])

		val content = #['"screenshot": "screenshots/firstScreenshot.png"', '"screenshot": "screenshots/secondScreenshot.png"']

		// when
		callTreeNodeArtifactFile.write(content, UTF_8, WRITE, APPEND, CREATE)
		assertThat(callTreeNodeArtifactFile).exists

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		val contentCaptor = ArgumentCaptor.forClass(InputStream)
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(fullId), eq(workspace.root.toPath.relativize(callTreeNodeArtifactFile).toString),
			contentCaptor.capture)
		assertThat(IOUtils.readLines(contentCaptor.value, UTF_8)).containsExactly(content)
	}

	@Test
	def void skipsOverNonExistingTestArtifactsGracefully() {
		val baseId = new TestExecutionKey('suiteId', 'suiteRunId')
		val fullId = baseId.deriveWithCaseRunId('caseRunId').deriveWithCallTreeId('callTreeId')
		testResultWatcher.watch(baseId)
		val screenshotsDir = workspace.newFolder('screenshots')
		val existingScreenshotFile = new File(screenshotsDir, 'existingScreenshot.png').toPath.createFile

		val testArtifactDir = new File(workspace.newFolder('.testexecution'), 'artifacts')
		val suiteDir = new File(testArtifactDir, fullId.suiteId)
		val suiteRunDir = new File(suiteDir, fullId.suiteRunId)
		val testRunDir = new File(suiteRunDir, fullId.caseRunId)
		val callTreeNodeArtifactFile = new File(testRunDir, fullId.callTreeId + '.yaml').toPath
		testRunDir.mkdirs

		when(screenshotFinderMock.toTestExecutionKey(eq(suiteRunDir.toPath))).thenReturn(baseId)
		when(screenshotFinderMock.toTestExecutionKey(eq(callTreeNodeArtifactFile))).thenReturn(fullId)
		when(screenshotFinderMock.getScreenshotPathsForTestStep(eq(fullId))).thenReturn(
			#['screenshots/nonExistingScreenshot.png', 'screenshots/existingScreenshot.png'])

		val content = #['"screenshot": "screenshots/nonExistingScreenshot.png"', '"screenshot": "screenshots/existingScreenshot.png"']

		// when
		callTreeNodeArtifactFile.write(content, UTF_8, WRITE, APPEND, CREATE)
		assertThat(callTreeNodeArtifactFile).exists

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(fullId), eq(workspace.root.toPath.relativize(existingScreenshotFile).toString),
			any(InputStream))
	}

	@Test
	def void uploadsCorrectFileContent() {
		// given
		val jobId = new TestExecutionKey('jobId')
		testResultWatcher.watch(jobId)
		val logFile = new File(workspace.newFolder('logs'), '''testrun.«jobId.toString».1912-06-23.log''').toPath
		val uploadStream = ArgumentCaptor.forClass(LogTail2Stream)

		// when
		logFile.createFile
		logFile.write(#['Hello', 'World'], UTF_8, WRITE, APPEND)

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(jobId), eq(workspace.root.toPath.relativize(logFile).toString),
			uploadStream.capture)

		val out = new ByteArrayOutputStream
		uploadStream.value => [
			stop
			write(out)
			assertThat(out.toString(UTF_8)).isEqualTo('''
				Hello
				World
			'''.toString)

		]
	}

	@Test
	def void uploadsCorrectFileContentFromRepeatedWrites() {
		// given
		val jobId = new TestExecutionKey('jobId')
		testResultWatcher.watch(jobId)
		val logFile = new File(workspace.newFolder('logs'), '''testrun.«jobId.toString».1912-06-23.log''').toPath
		val uploadStream = ArgumentCaptor.forClass(LogTail2Stream)

		// when
		logFile.createFile
		logFile.write(#['Hello'], UTF_8, WRITE, APPEND)
		logFile.write(#['World'], UTF_8, WRITE, APPEND)

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(jobId), eq(workspace.root.toPath.relativize(logFile).toString),
			uploadStream.capture)
		val out = new ByteArrayOutputStream
		uploadStream.value => [
			stop
			write(out)
			assertThat(out.toString(UTF_8)).isEqualTo('''
				Hello
				World
			'''.toString)

		]
	}

	@Test
	def void registersToWatchAllSubdirectoriesRecursively() {
		// given
		val jobId = new TestExecutionKey('jobId')
		val logDir = workspace.newFolder('logs')
		val nestedDir = workspace.newFolder('sampleDir', 'nestedDir')

		val logFile = new File(logDir, '''testrun.«jobId.toString».1912-06-23.log''').toPath
		val anotherFile = new File(nestedDir, '''testrun.«jobId.toString».1912-06-23.another.log''').toPath

		// when
		testResultWatcher.watch(jobId)
		logFile.createFile
		anotherFile.createFile

		// then
		executor.shutdown()
		executor.awaitTermination(5, TimeUnit.SECONDS)
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(jobId), eq(workspace.root.toPath.relativize(logFile).toString), any(LogTail2Stream))
		verify(managerClientMock).upload(eq(workerUrl.toString), eq(jobId), eq(workspace.root.toPath.relativize(anotherFile).toString),
			any(LogTail2Stream))
	}

}
