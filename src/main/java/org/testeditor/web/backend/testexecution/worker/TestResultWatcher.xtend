package org.testeditor.web.backend.testexecution.worker

import com.sun.nio.file.SensitivityWatchEventModifier
import java.io.File
import java.nio.file.FileSystems
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.StandardWatchEventKinds
import java.nio.file.WatchKey
import java.util.concurrent.Executor
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Provider
import javax.inject.Singleton
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration
import org.testeditor.web.backend.testexecution.screenshots.ScreenshotFinder

import static java.nio.file.StandardOpenOption.READ
import static java.nio.file.StandardWatchEventKinds.ENTRY_CREATE
import static java.nio.file.StandardWatchEventKinds.ENTRY_MODIFY

import static extension java.nio.file.Files.exists
import static extension java.nio.file.Files.isRegularFile
import static extension java.nio.file.Files.newInputStream
import static extension java.nio.file.Files.walk

@Singleton
class TestResultWatcher {

	static val logger = LoggerFactory.getLogger(TestResultWatcher)
	static val artifactRegistryPath = Paths.get('.testexecution/artifacts')

	val watchService = FileSystems.getDefault.newWatchService
	val TestExecutionManagerClient managerClient
	var TestExecutionKey currentJob
	val Path workspace
	val extension ScreenshotFinder screenshotFinder
	val testArtifactRegistryMatcher = FileSystems.getDefault().getPathMatcher('''glob:**/«artifactRegistryPath»/**.yaml''')
	val String workerUrl
	val watchedDirectories = <WatchKey, Path>newHashMap
	val alreadyHandled = <Path>newHashSet

	@Inject
	new(@Named("workspace") Provider<File> workspaceProvider, TestExecutionManagerClient managerClient, @Named("watcherExecutor") Executor executor,
		ScreenshotFinder screenshotFinder, TestExecutionDropwizardConfiguration config) {
		this.managerClient = managerClient
		this.workspace = workspaceProvider.get.toPath
		workspace.watchDirectory
		workspace.resolve(artifactRegistryPath) => [
			if (exists) {
				watchDirectory
			}
		]
		executor.execute[startWatching]
		this.screenshotFinder = screenshotFinder
		this.workerUrl = config.workerUrl.toString
	}

	def void watch(TestExecutionKey currentJob) {
		logger.info('''Watching files created by job "«currentJob»"''')
		this.currentJob = currentJob
	}

	private def void startWatching() {
		var WatchKey key
		try {
			while ((key = watchService.take) !== null) {
				val watchKey = key
				val events = key.pollEvents
				logger.info('''received new batch of file system events («key»)''')
				if (currentJob !== null) {
					if (events.empty) {
						logger.warn('''no events''')
					}
					events.reject [
						kind == StandardWatchEventKinds.OVERFLOW => [
							logger.warn('cannot keep up with file system events')
						]
					].map [
						logger.info('''detected "«kind»" at path "«context»"''')
						watchedDirectories.get(watchKey).resolve(context as Path)
					].forEach[watchOrUpload]
				} else {
					logger.info('discarding event (no job to watch)')
				}
				logger.info('processed current batch of file system events')
				key.reset
			}
		} catch (InterruptedException ex) {
			logger.info('cancelling')
			if (key !== null) {
				key.cancel
			}
			watchService.close
		}
		logger.info('stopped watching for test result files')
	}

	private def void watchDirectory(Path dir) {
		watchedDirectories.put(dir.register(watchService, #[ENTRY_CREATE, ENTRY_MODIFY], SensitivityWatchEventModifier.HIGH), dir)
	}

	private def void watchOrUpload(Path it) {
		walk.forEach [
			if (isRegularFile) {
				if (isLogFile) {
					handleLogs
				} else if (isArtifactRegistry) {
					handleArtifacts
				} else {
					logger.info('''ignoring file "«it»", not relevant for current job "«currentJob»"''')
				}
			} else {
				logger.info('''watching directory "«toString»"''')
				watchDirectory
			}
		]
	}

	private def boolean isLogFile(Path it) {
		return fileName.toString.matches('''.*«currentJob».*''')
	}

	private def boolean isArtifactRegistry(Path it) {
		return testArtifactRegistryMatcher.matches(it) => [ match |
			logger.info('''is path «it» an artifact repository? «IF match»yes«ELSE»no«ENDIF»''')
		] && (dropWhile[it != artifactRegistryPath.last].drop(1).take(2) => [
			logger.info('''artifact registry entry belongs to job with suite id "«head»" and suite run id "«last»"''')
		]).map[toString].elementsEqual(#[currentJob.suiteId, currentJob.suiteRunId])
	}

	private def void handleArtifacts(Path it) {
		val key = toTestExecutionKey
		if (key.suiteId == currentJob.suiteId && key.suiteRunId == currentJob.suiteRunId) {
			logger.info('''reading new test artifact registry entries for key "«key»"''')
			key.screenshotPathsForTestStep.forEach [
				workspace.resolve(it).upload(key, it)
			]
		} else {
			logger.info('''ignoring file "«it»", not relevant for current job "«currentJob»"''')
		}

	}

	private def void handleLogs(Path it) {
		upload(currentJob, workspace.relativize(it).toString)
	}

	private def upload(Path fileToStream, TestExecutionKey key, String relativePath) {
		if (alreadyHandled.contains(fileToStream)) {
			logger.info('''skipping file "«relativePath»" (already uploaded)''')
		} else {
			logger.info('''starting to upload file «relativePath» to test execution manager''')
			alreadyHandled.add(fileToStream)
			managerClient.upload(workerUrl, key, relativePath, fileToStream.newInputStream(READ))
		}
	}

}
