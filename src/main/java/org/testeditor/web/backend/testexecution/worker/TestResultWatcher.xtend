package org.testeditor.web.backend.testexecution.worker

import com.sun.nio.file.SensitivityWatchEventModifier
import java.io.File
import java.io.IOException
import java.nio.file.FileSystems
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.SimpleFileVisitor
import java.nio.file.StandardWatchEventKinds
import java.nio.file.WatchKey
import java.nio.file.attribute.BasicFileAttributes
import java.nio.file.attribute.FileTime
import java.time.Instant
import java.util.Set
import java.util.concurrent.Executor
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Provider
import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration
import org.testeditor.web.backend.testexecution.screenshots.ScreenshotFinder

import static java.nio.file.FileVisitResult.*
import static java.nio.file.StandardOpenOption.READ
import static java.nio.file.StandardWatchEventKinds.ENTRY_CREATE
import static java.nio.file.StandardWatchEventKinds.ENTRY_MODIFY

import static extension java.nio.file.Files.exists
import static extension java.nio.file.Files.getLastModifiedTime
import static extension java.nio.file.Files.isDirectory
import static extension java.nio.file.Files.isRegularFile
import static extension java.nio.file.Files.newInputStream
import static extension java.nio.file.Files.walkFileTree
import java.util.concurrent.Phaser
import java.util.concurrent.TimeUnit

@Singleton
class TestResultWatcher {

	static val logger = LoggerFactory.getLogger(TestResultWatcher)
	static val artifactRegistryPath = Paths.get('.testexecution/artifacts')
	static val IGNORE_PATTERN = '\\._.+\\.tmp'

	val watchService = FileSystems.getDefault.newWatchService
	val TestExecutionManagerClient managerClient
	val Phaser phaser = new Phaser
	volatile int startPhase
	volatile TestExecutionKey currentJob
	val Path workspace
	val extension ScreenshotFinder screenshotFinder
	val testArtifactRegistryMatcher = FileSystems.getDefault().getPathMatcher('''glob:**/«artifactRegistryPath»/**.yaml''')
	val String workerUrl
	val watchedDirectories = <WatchKey, Path>newHashMap
	val lastHandled = <Path, FileTime>newHashMap
	val Set<LogTail2Stream> logtails = <LogTail2Stream>newHashSet
	val boolean useLogTailing


	@Inject
	new(@Named("workspace") Provider<File> workspaceProvider, TestExecutionManagerClient managerClient, @Named("watcherExecutor") Executor executor,
		ScreenshotFinder screenshotFinder, TestExecutionDropwizardConfiguration config) {
		this.managerClient = managerClient
		this.workspace = workspaceProvider.get.toPath
		workspace.walkFileTree(new WorkspaceVisitor(workspace) [
			if (isDirectory) {
				watchDirectory
			}
		])
		executor.execute[startWatching]
		this.screenshotFinder = screenshotFinder
		this.workerUrl = config.workerUrl.toString
		this.useLogTailing = config.useLogTailing
	}

	def void watch(TestExecutionKey currentJob) {
		if (currentJob !== null) {
			this.startPhase = phaser.phase
			logger.info('''Watching files created by job "«currentJob»"''')
			this.currentJob = currentJob
		} else {
			throw new NullPointerException('the job to watch must never be set to null')
		}
	}
	
	def boolean hasAdvanced() {
		return phaser.phase > startPhase
	}
	
	def void waitForWatchPhase() {
		phaser.awaitAdvanceInterruptibly(phaser.phase, 2200, TimeUnit.MILLISECONDS)
	}

	def void stopWatching() {
		if (!logtails.empty) {
			logger.info('''Stopping log tails''')
			logtails.forEach[stop]
			logtails.clear
		}
	}

	private def void startWatching() {
		var WatchKey key
		try {
			while ((key = watchService.take) !== null) {
				phaser.register
				val watchKey = key
				val events = key.pollEvents
				logger.info('''received new batch of file system events («key»)''')
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
				logger.info('processed current batch of file system events')
				phaser.arriveAndDeregister
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
		logger.info('''watching directory «dir»''')
		watchedDirectories.put(dir.register(watchService, #[ENTRY_CREATE, ENTRY_MODIFY], SensitivityWatchEventModifier.HIGH), dir)
	}

	private def void watchOrUpload(Path it) {
		walkFileTree(new WorkspaceVisitor(workspace) [
			if (isRegularFile) {
				if (currentJob !== null) {
					if (isLogFile) {
						handleLogs
					} else if (isArtifactRegistry) {
						handleArtifacts
					} else {
						logger.info('''ignoring file "«it»", not relevant for current job "«currentJob»"''')
					}
				} else {
					logger.info('discarding event (no job to watch)')
				}
			} else {
				watchDirectory
			}
		])
	}

	private def boolean isLogFile(Path it) {
		return fileName.toString.matches('''.*«currentJob».*(log|yaml|yml)''')
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
			workspace.resolve(it).upload(key, workspace.relativize(it).toString)
		} else {
			logger.info('''ignoring file "«it»", not relevant for current job "«currentJob»"''')
		}

	}

	private def void handleLogs(Path it) {
		upload(currentJob, workspace.relativize(it).toString, useLogTailing)
	}

	private def upload(Path fileToStream, TestExecutionKey key, String relativePath) {
		fileToStream.upload(key, relativePath, false)
	}

	private def upload(Path fileToStream, TestExecutionKey key, String relativePath, boolean tail) {
		if (!fileToStream.exists) {
			logger.error('''cannot upload non-existing but registered test artifact file "«relativePath»"''')
		} else {
			fileToStream.uploadExisting(key, relativePath, tail)
		}
	}

	private def uploadExisting(Path fileToStream, TestExecutionKey key, String relativePath, boolean tail) {
		val lastUploadedVersion = lastHandled.getOrDefault(fileToStream, FileTime.from(Instant.MIN))
		val lastModified = fileToStream.lastModifiedTime
		if (lastUploadedVersion > lastModified) {
			logger.info('''skipping file "«relativePath»" (already uploaded)''')
		} else {
			lastHandled.put(fileToStream, lastModified)
			fileToStream.uploadNewer(key, relativePath, tail)
		}
	}

	private def uploadNewer(Path fileToStream, TestExecutionKey key, String relativePath, boolean tail) {
		logger.info('''starting to upload file «relativePath» to test execution manager''')
		if (tail) {
			val logTail = new LogTail2Stream(fileToStream.toFile /*, [statusManager.status !== TestStatus.RUNNING]*/ )
			this.logtails.add(logTail)
			managerClient.upload(workerUrl, key, relativePath, logTail)
		} else {
			managerClient.upload(workerUrl, key, relativePath, fileToStream.newInputStream(READ))
		}
	}

	@FinalFieldsConstructor
	static class WorkspaceVisitor extends SimpleFileVisitor<Path> {

		static val logger = LoggerFactory.getLogger(WorkspaceVisitor)

		val Path workspaceRoot
		val (Path)=>void action

		override preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
			return if (dir.isDirectory) {
				if (dir.parent == workspaceRoot && dir.fileName.toString == ".git") {
					SKIP_SUBTREE
				} else {
					action.apply(dir)
					CONTINUE
				}
			} else {
				CONTINUE
			}
		}

		override visitFile(Path file, BasicFileAttributes attrs) throws IOException {
			if (!file.fileName.toString.matches(IGNORE_PATTERN)) {
				action.apply(file)
			}
			return CONTINUE
		}

		override visitFileFailed(Path file, IOException exc) throws IOException {
			if (!file.fileName.toString.matches(IGNORE_PATTERN)) {
				logger.warn('''problem occurred when trying to access file «file»: «exc.message»''', exc)
			}
			return CONTINUE
		}

	}

}
