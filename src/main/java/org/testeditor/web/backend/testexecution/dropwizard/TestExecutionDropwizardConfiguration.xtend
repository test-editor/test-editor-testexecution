package org.testeditor.web.backend.testexecution.dropwizard

import com.fasterxml.jackson.annotation.JsonProperty
import io.dropwizard.client.JerseyClientConfiguration
import javax.inject.Singleton
import javax.validation.Valid
import javax.validation.constraints.NotNull
import org.eclipse.xtend.lib.annotations.Accessors
import org.hibernate.validator.constraints.NotEmpty
import org.testeditor.web.dropwizard.DropwizardApplicationConfiguration

@Singleton
class TestExecutionDropwizardConfiguration extends DropwizardApplicationConfiguration implements TestExecutionConfiguration, GitConfiguration {
	
    @Valid
    @NotNull
    var JerseyClientConfiguration jerseyClient = new JerseyClientConfiguration

    @JsonProperty("jerseyClient")
    def JerseyClientConfiguration getJerseyClientConfiguration() {
        return jerseyClient
    }

    @JsonProperty("jerseyClient")
    def void setJerseyClientConfiguration(JerseyClientConfiguration jerseyClient) {
        this.jerseyClient = jerseyClient
    }
	
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
    Boolean filterTestSubStepsFromLogs = false

}
