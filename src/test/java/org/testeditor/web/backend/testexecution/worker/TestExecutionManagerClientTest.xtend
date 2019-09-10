package org.testeditor.web.backend.testexecution.worker

import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.URL
import javax.inject.Provider
import javax.ws.rs.core.StreamingOutput
import org.apache.commons.io.IOUtils
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.dropwizard.RestClient
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionDropwizardConfiguration

import static java.net.URLEncoder.encode
import static java.nio.charset.StandardCharsets.UTF_8
import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.verify
import static org.mockito.Mockito.when

@RunWith(MockitoJUnitRunner)
class TestExecutionManagerClientTest {

	@Mock
	RestClient restClient

	@Mock
	Provider<RestClient> restClientProvider

	@Mock
	TestExecutionDropwizardConfiguration config

	@InjectMocks
	val managerClient = new TestExecutionManagerClient

	static val managerUri = 'http://test-editor.example.org/testexecution/manager/workers'
	static val workerId = 'http://worker.example.org/te-worker'

	@Before
	def void setupMocks() {
		when(restClientProvider.get).thenReturn(restClient)
		when(config.testExecutionManagerUrl).thenReturn(new URI(managerUri))
		when(config.workerUrl).thenReturn(new URL(workerId))
	}

	@Test
	def void uploadsContentViaRestToManager() {
		// given
		val jobId = new TestExecutionKey('jobId')
		val fileName = 'path/to/file'
		val content = '''
			Hello
			World
		'''

		// when
		managerClient.upload(workerId, jobId, fileName, IOUtils.toInputStream(content, UTF_8))

		// then
		val streamingOutputCaptor = ArgumentCaptor.forClass(StreamingOutput)
		verify(restClient).postAsync(eq(new URI('''«managerUri»/«encode(workerId+'/worker', UTF_8)»/«encode(jobId.toString, UTF_8)»/«encode(fileName, UTF_8)»''')),
			streamingOutputCaptor.capture)
		val actualOutput = new ByteArrayOutputStream()
		streamingOutputCaptor.value.write(actualOutput)
		assertThat(actualOutput.toString).isEqualTo(content)
		
	}

}
