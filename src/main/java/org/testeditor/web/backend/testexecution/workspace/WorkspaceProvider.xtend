package org.testeditor.web.backend.testexecution.workspace

import java.io.File
import javax.inject.Inject
import javax.inject.Provider
import org.testeditor.web.backend.testexecution.dropwizard.GitConfiguration

class WorkspaceProvider implements Provider<File> {
	
	@Inject extension GitConfiguration
	
	override get() {
		return new File(localRepoFileRoot)
	}
	
}