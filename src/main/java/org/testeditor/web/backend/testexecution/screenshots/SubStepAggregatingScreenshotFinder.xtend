package org.testeditor.web.backend.testexecution.screenshots

import java.util.Optional
import javax.inject.Inject
import org.testeditor.web.backend.testexecution.TestExecutionCallTree
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.TestExecutorProvider

class SubStepAggregatingScreenshotFinder implements ScreenshotFinder {

	@Inject
	TestArtifactRegistryScreenshotFinder delegateFinder
	@Inject
	TestExecutionCallTree callTree
	@Inject
	TestExecutorProvider executorProvider

	override getScreenshotPathsForTestStep(TestExecutionKey key) {
		var result = delegateFinder.getScreenshotPathsForTestStep(key)
		if (result.nullOrEmpty) {
			val latestCallTree = executorProvider.getTestFiles(new TestExecutionKey(key.suiteId, key.suiteRunId)) //
			.filter[name.endsWith('.yaml')].sortBy[name].last
			callTree.readFile(key, latestCallTree)

			result = callTree.getDescendantsKeys(key) //
			.map[delegateFinder.getScreenshotPathsForTestStep(it)] //
			.reduce[list1, list2|list1 + list2]
		}
		return Optional.ofNullable(result).orElse(#[])
	}

}
