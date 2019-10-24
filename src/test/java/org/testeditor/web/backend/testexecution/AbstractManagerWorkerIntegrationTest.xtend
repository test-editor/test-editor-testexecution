package org.testeditor.web.backend.testexecution

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import de.xtendutils.junit.AssertionHelper
import io.dropwizard.testing.ConfigOverride
import io.dropwizard.testing.ResourceHelpers
import io.dropwizard.testing.junit.DropwizardAppRule
import java.io.File
import java.nio.file.Path
import java.util.List
import javax.ws.rs.client.Entity
import javax.ws.rs.client.Invocation.Builder
import javax.ws.rs.core.MediaType
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.junit.JGitTestUtil
import org.eclipse.jgit.revwalk.RevCommit
import org.glassfish.jersey.client.ClientProperties
import org.junit.Before
import org.junit.rules.TemporaryFolder
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.dropwizard.ManagerApplication
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration

import static io.dropwizard.testing.ConfigOverride.config

abstract class AbstractManagerWorkerIntegrationTest {

	protected extension val TestUtils = new TestUtils

	protected static val String userId = 'john.doe'
	protected val String serverPort = freePort
	protected val String token = createToken

	protected val TemporaryFolder managerWorkspace = new TemporaryFolder
	protected val TemporaryFolder workerWorkspace = new TemporaryFolder
	protected val TemporaryFolder remoteGitFolder = new TemporaryFolder

	protected def List<ConfigOverride> getConfigs() {
		return #[
			config('logging.level', 'INFO'),
			config('server.applicationConnectors[0].port', serverPort),
			config('localRepoFileRoot', [managerWorkspace.root.path]),
			config('remoteRepoUrl', [setupRemoteGitRepository])
		]
	}

	static def String createToken() {
		return createToken(userId, 'John Doe', 'john@example.org')
	}

	static def String createToken(String id, String name, String eMail) {
		val builder = JWT.create => [
			withClaim('id', id)
			withClaim('name', name)
			withClaim('email', eMail)
		]
		return builder.sign(Algorithm.HMAC256("secret"))
	}

	var DropwizardAppRule<TestExecutionDropwizardConfiguration> dropwizardServer

	def DropwizardAppRule<TestExecutionDropwizardConfiguration> getDropwizardAppRule() {
		if (dropwizardServer === null) {
			dropwizardServer = new DropwizardAppRule(ManagerApplication, ResourceHelpers.resourceFilePath('test-config.yml'), configs)
		}
		return dropwizardServer
	}

	protected extension val AssertionHelper = AssertionHelper.instance

	def String setupRemoteGitRepository() {
		if (!new File(remoteGitFolder.root, '.git').exists) {
			val git = Git.init.setDirectory(remoteGitFolder.root).call
			git.populatedRemoteGit
		}
		return "file://" + remoteGitFolder.root.absolutePath
	}

	protected def void populatedRemoteGit(Git git) {
		JGitTestUtil.writeTrashFile(git.repository, 'README.md', '# Readme')
		git.add.addFilepattern("README.md").call
		git.commit.setMessage("Initial commit").call
	}

	protected def RevCommit commitInRemoteRepository(String pathToCommit) {
		val git = Git.open(remoteGitFolder.root)
		git.add.addFilepattern(pathToCommit).call
		return git.commit.setMessage("pre-existing commit in remote repository").call
	}

	protected def void commitInRemoteRepository(Path pathToCommit) {
		commitInRemoteRepository(remoteGitFolder.root.toPath.relativize(pathToCommit).toString)
	}

	protected def void commitInRemoteRepository(File fileToCommit) {
		commitInRemoteRepository(fileToCommit.toPath)
	}

	@Before
	def void setClientTimeouts() {
		dropwizardAppRule.client.property(ClientProperties.CONNECT_TIMEOUT, 100000);
		dropwizardAppRule.client.property(ClientProperties.READ_TIMEOUT, 100000);
	}

	def Entity<String> stringEntity(CharSequence charSequence) {
		return Entity.entity(charSequence.toString, MediaType.TEXT_PLAIN)
	}

	def Builder createRequest(String relativePath) {
		return createRequest(relativePath, token)
	}
	

	def Builder createRequest(String relativePath, DropwizardAppRule<TestExecutionDropwizardConfiguration> appRule) {
		return createRequest(relativePath, token, appRule)
	}

	protected def Builder createRequest(String relativePath, String customToken) {
		val uri = '''http://localhost:«dropwizardAppRule.localPort»/«relativePath»'''
		return createUrlRequest(uri, customToken)
	}
	
	protected def Builder createRequest(String relativePath, String customToken, DropwizardAppRule<TestExecutionDropwizardConfiguration> appRule) {
		val uri = '''http://localhost:«appRule.localPort»/«relativePath»'''
		return createUrlRequest(uri, customToken, appRule)
	}

	protected def Builder createUrlRequest(String uri) {
		return createUrlRequest(uri, token)
	}
	
	protected def Builder createUrlRequest(String uri, DropwizardAppRule<TestExecutionDropwizardConfiguration> appRule) {
		return createUrlRequest(uri, token, appRule)
	}

	protected def Builder createUrlRequest(String uri, String customToken) {
		return createUrlRequest(uri, customToken, dropwizardAppRule)
	}
	
	protected def Builder createUrlRequest(String uri, String customToken, DropwizardAppRule<TestExecutionDropwizardConfiguration> appRule) {
		val builder = appRule.client.target(uri).request
		builder.header('Authorization', '''Bearer «customToken»''')
		return builder
	}

	protected def Builder createCallTreeRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»''')
	}

	protected def Builder createLaunchNewRequest() {
		return createRequest('''test-suite/launch-new''')
	}

	protected def Builder createTestRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»?status&wait''')
	}

	protected def Builder createAsyncTestRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»?status''')
	}

	protected def Builder createNodeRequest(TestExecutionKey key) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»/«key.caseRunId»/«key.callTreeId»''')
	}

	protected def Builder createNodeRequest(TestExecutionKey key, String queryParams) {
		return createRequest('''test-suite/«key.suiteId»/«key.suiteRunId»/«key.caseRunId»/«key.callTreeId»?«queryParams»''')
	}

}