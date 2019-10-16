package org.testeditor.web.backend.testexecution.screenshots

import java.io.File
import java.util.Optional
import javax.inject.Inject
import javax.inject.Named
import org.testeditor.web.backend.testexecution.TestExecutionCallTree
import org.testeditor.web.backend.testexecution.common.TestExecutionKey

class SubStepAggregatingScreenshotFinder implements ScreenshotFinder {

	@Inject
	TestArtifactRegistryScreenshotFinder delegateFinder
	@Inject
	TestExecutionCallTree callTree
	@Inject @Named('workspace')
	File workspace

	override getScreenshotPathsForTestStep(TestExecutionKey key) {
		var result = delegateFinder.getScreenshotPathsForTestStep(key)
		if (result.nullOrEmpty) {
			val latestCallTree = new TestExecutionKey(key.suiteId, key.suiteRunId).getTestFiles(workspace) //
			.filter[name.endsWith('.yaml')].sortBy[name].last
			callTree.readFile(key, latestCallTree)

			result = callTree.getDescendantsKeys(key) //
			.map[delegateFinder.getScreenshotPathsForTestStep(it)] //
			.reduce[list1, list2|list1 + list2]
		}
		return Optional.ofNullable(result).orElse(#[])
	}

}
