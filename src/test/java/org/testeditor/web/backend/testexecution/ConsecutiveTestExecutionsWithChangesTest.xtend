package org.testeditor.web.backend.testexecution

import java.io.File
import javax.inject.Provider
import org.apache.commons.io.FileUtils
import org.apache.commons.io.IOUtils
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionConfiguration

import static java.nio.charset.StandardCharsets.UTF_8
import static java.util.concurrent.TimeUnit.SECONDS
import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.Mockito.when

@RunWith(MockitoJUnitRunner)
class ConsecutiveTestExecutionsWithChangesTest {
	static val WORKSPACE_DIR = 'src/test/resources/consecutive-test-executions-with-changes-bug'
	static val TESTFILE_PATH = 'src/test/java/sample/SampleTest.tcl'
	static val BACKUP_FILE = new File('SampleTest.tcl.bak') 
	
	@Mock Provider<File> mockWorkspaceProvider
	@Mock TestExecutionConfiguration mockConfig
	@InjectMocks TestExecutorProvider executorUnderTest
	
	@Before
	def void backupTestFile() {
		FileUtils.copyFile(new File(WORKSPACE_DIR + '/' + TESTFILE_PATH), BACKUP_FILE)
	}
	
	@After
	def void restoreTestFile() {
		FileUtils.copyFile(BACKUP_FILE, new File(WORKSPACE_DIR, TESTFILE_PATH))
		BACKUP_FILE.delete
	}
	
	@After
	def void deleteBuildDir() {
		FileUtils.deleteDirectory(new File(WORKSPACE_DIR + '/build'))
	}
	
	@Test
	def void consecutiveTestExecutionAfterChangeTest() {
		// given
		val workspace = new File(WORKSPACE_DIR)
		when(mockWorkspaceProvider.get).thenReturn(workspace)
		val testClass = 'sample.SampleTest'
		val firstTestKey = new TestExecutionKey('0', '0')
		val secondTestKey = new TestExecutionKey('0', '1')	
		
		// when
		val firstProcess = executorUnderTest.testExecutionBuilder(firstTestKey, #[testClass], '4711').start
		firstProcess.waitFor(60, SECONDS)
		
		workspace.introduceChange
		
		val secondProcess = executorUnderTest.testExecutionBuilder(secondTestKey, #[testClass], '4711').start
		secondProcess.waitFor(60, SECONDS)

		// then
		val outputLines = IOUtils.readLines(secondProcess.inputStream, UTF_8)
		val lastLines = outputLines.drop(outputLines.length-10)
		assertThat(lastLines).anyMatch[startsWith('BUILD SUCCESSFUL')]
	}
	
	private def introduceChange(File workspace) {
		val testFile = new File (workspace, TESTFILE_PATH)
		FileUtils.writeStringToFile(testFile, ' ', UTF_8, true)
	}

}
