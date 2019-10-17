package org.testeditor.web.backend.testexecution.screenshots

import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.testexecution.TestExecutionCallTree
import org.testeditor.web.backend.testexecution.TestExecutorProvider
import org.testeditor.web.backend.testexecution.common.TestExecutionKey

import static org.assertj.core.api.Assertions.assertThat
import static org.mockito.ArgumentMatchers.*
import static org.mockito.Mockito.mock
import static org.mockito.Mockito.when
import static org.mockito.Mockito.doReturn
import static org.mockito.Mockito.spy
import java.util.Optional
import java.io.File
import org.testeditor.web.backend.testexecution.util.serialization.YamlReader

@RunWith(MockitoJUnitRunner)
class SubStepAggregatingScreenshotFinderTest {

	@Mock TestArtifactRegistryScreenshotFinder mockDelegate
	@Mock TestExecutionCallTree mockCallTree
	@Mock YamlReader mockYamlReader

	@InjectMocks SubStepAggregatingScreenshotFinder finderUnderTest

	
	@Test
	def void retrievesScreenshotsOfSubStepsIfNodeHasNoneOfItsOwn() {
		// given
		val key = spy(TestExecutionKey.valueOf('0-0-0-1'))
		val childKeys = #['0-0-0-2', '0-0-0-3', '0-0-0-4'].map[TestExecutionKey.valueOf(it)]
		
		doReturn(key).when(key).deriveWithSuiteRunId
		doReturn(Optional.of(mock(File))).when(key).getLatestCallTree(any)
		
		when(mockYamlReader.readYaml(any(File))).thenReturn(#{})
		
		when(mockDelegate.getScreenshotPathsForTestStep(key)).thenReturn(#[])
		childKeys.forEach[when(mockDelegate.getScreenshotPathsForTestStep(it)).thenReturn(#['''path/to/screenshot-«callTreeId».png'''])]
		
		when(mockCallTree.getDescendantsKeys(eq(key), any)).thenReturn(childKeys)

		// when
		val actualScreenshots = finderUnderTest.getScreenshotPathsForTestStep(key)

		// then
		assertThat(actualScreenshots).containsExactly('path/to/screenshot-2.png', 'path/to/screenshot-3.png', 'path/to/screenshot-4.png')
	}

}
