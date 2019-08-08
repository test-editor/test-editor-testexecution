package org.testeditor.web.backend.testexecution.dropwizard

import javax.inject.Singleton
import org.eclipse.xtend.lib.annotations.Accessors
import org.hibernate.validator.constraints.NotEmpty
import org.testeditor.web.dropwizard.DropwizardApplicationConfiguration

@Singleton
class TestExecutionDropwizardConfiguration extends DropwizardApplicationConfiguration implements TestExecutionConfiguration, GitConfiguration {
	
	@NotEmpty
	@Accessors
	String localRepoFileRoot = 'repo'
	
	@NotEmpty
	@Accessors
	String remoteRepoUrl

	@NotEmpty 
	@Accessors
	String branchName = 'master'
	
	@Accessors
	String privateKeyLocation

	@Accessors
	String knownHostsLocation

	@Accessors
	String xvfbrunPath
	
	@Accessors
	String nicePath
	
	@Accessors
	String shPath	
	
	@Accessors
	Boolean filterTestSubStepsFromLogs

}
