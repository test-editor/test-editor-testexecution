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
import static org.mockito.Mockito.when

@RunWith(MockitoJUnitRunner)
class SubStepAggregatingScreenshotFinderTest {

	@Mock TestArtifactRegistryScreenshotFinder mockDelegate
	@Mock TestExecutionCallTree mockCallTree
	@Mock TestExecutorProvider mockExecutorProvider

	@InjectMocks SubStepAggregatingScreenshotFinder finderUnderTest

	// DONOT USE, introduces usage of an element used for InjectMocks but not used anywhere else, makeing the IDE report an annoying warning
	protected def dummyUsageOfInjected() {
		mockExecutorProvider
	}
	
	@Test
	def void retrievesScreenshotsOfSubStepsIfNodeHasNoneOfItsOwn() {
		// given
		val key = TestExecutionKey.valueOf('0-0-0-1')
		val childKeys = #['0-0-0-2', '0-0-0-3', '0-0-0-4'].map[TestExecutionKey.valueOf(it)]
		when(mockDelegate.getScreenshotPathsForTestStep(key)).thenReturn(#[])
		childKeys.forEach[when(mockDelegate.getScreenshotPathsForTestStep(it)).thenReturn(#['''path/to/screenshot-«callTreeId».png'''])]
		when(mockCallTree.getDescendantsKeys(key)).thenReturn(childKeys)

		// when
		val actualScreenshots = finderUnderTest.getScreenshotPathsForTestStep(key)

		// then
		assertThat(actualScreenshots).containsExactly('path/to/screenshot-2.png', 'path/to/screenshot-3.png', 'path/to/screenshot-4.png')
	}

}
