package org.testeditor.web.backend.testexecution.workspace

import java.io.File
import javax.inject.Inject
import javax.inject.Provider
import org.eclipse.jgit.lib.BranchConfig
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.dropwizard.GitConfiguration
import org.testeditor.web.backend.testexecution.git.GitProvider
import org.testeditor.web.dropwizard.auth.User

import static org.eclipse.jgit.api.ResetCommand.ResetType.HARD

class WorkspaceProvider implements Provider<File> {

	static val logger = LoggerFactory.getLogger(WorkspaceProvider)

	@Inject extension GitConfiguration
	@Inject extension GitProvider
	@Inject Provider<User> userProvider

	override get() {
		return new File(localRepoFileRoot) => [
			logger.info('fetching latest changes from remote repository')
			git.fetch.configureTransport.call
			val remoteTrackingBranch = new BranchConfig(git.repository.config, git.repository.branch).remoteTrackingBranch
			git.reset => [
				mode = HARD
				ref = remoteTrackingBranch
				call
			]
		]
	}

	/**
	 * Get a file in the workspace without updating first, e.g. for local files not under version control.
	 */
	def File getLocalWorkspaceFile(String resourcePath) {
		val workspace = new File(localRepoFileRoot)
		return new File(workspace, resourcePath) => [ file |
			if (!workspace.isValidPath(file)) {
				throw new MaliciousPathException(workspace.absolutePath, file.absolutePath, userProvider?.get?.name ?: '<UNKNOWN>')
			} else if (!file.exists) {
				throw new MissingFileException('''The file '«resourcePath»' does not exist.''')
			}
		]
	}

	private def boolean isValidPath(File workspace, File workspaceFile) {
		val workspacePath = workspace.canonicalPath
		val filePath = workspaceFile.canonicalPath
		return filePath.startsWith(workspacePath)
	}

}

@FinalFieldsConstructor
class TestArtifactAccessException extends Exception {

	@Accessors
	val String message

}

@Data
class MaliciousPathException extends TestArtifactAccessException {

	String workspacePath
	String resourcePath
	String userName

	new(String workspacePath, String resourcePath, String userName) {
		super('''User='«userName»' tried to access resource='«resourcePath»' which is not within its workspace='«workspacePath»'.''')
		this.workspacePath = workspacePath
		this.resourcePath = resourcePath
		this.userName = userName
	}

}

class MissingFileException extends TestArtifactAccessException {

	new(String message) {
		super(message)
	}

}
