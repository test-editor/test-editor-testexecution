package org.testeditor.web.backend.testexecution.workspace

import java.io.File
import javax.inject.Inject
import javax.inject.Provider
import org.testeditor.web.backend.testexecution.dropwizard.GitConfiguration
import org.testeditor.web.backend.testexecution.git.GitProvider

class WorkspaceProvider implements Provider<File> {
	
	@Inject extension GitConfiguration
	@Inject extension GitProvider
	
	override get() {
		return new File(localRepoFileRoot) => [
			git.pull.call		
		]
	}	
}
