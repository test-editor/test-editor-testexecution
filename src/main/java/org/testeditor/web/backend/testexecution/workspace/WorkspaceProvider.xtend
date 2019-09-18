package org.testeditor.web.backend.testexecution.workspace

import java.io.File
import javax.inject.Inject
import javax.inject.Provider
import org.eclipse.jgit.lib.BranchConfig
import org.slf4j.LoggerFactory
import org.testeditor.web.backend.testexecution.dropwizard.GitConfiguration
import org.testeditor.web.backend.testexecution.git.GitProvider

import static org.eclipse.jgit.api.ResetCommand.ResetType.HARD

class WorkspaceProvider implements Provider<File> {

	static val logger = LoggerFactory.getLogger(WorkspaceProvider)

	@Inject extension GitConfiguration
	@Inject extension GitProvider

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

}
