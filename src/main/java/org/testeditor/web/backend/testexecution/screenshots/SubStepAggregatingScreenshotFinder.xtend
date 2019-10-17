package org.testeditor.web.backend.testexecution.screenshots

import java.io.File
import java.util.Optional
import javax.inject.Inject
import javax.inject.Named
import org.testeditor.web.backend.testexecution.TestExecutionCallTree
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.util.serialization.YamlReader

class SubStepAggregatingScreenshotFinder implements ScreenshotFinder {

	@Inject
	TestArtifactRegistryScreenshotFinder delegateFinder
	@Inject
	TestExecutionCallTree callTree
	@Inject @Named('workspace')
	File workspace
	@Inject
	extension YamlReader

	override getScreenshotPathsForTestStep(TestExecutionKey key) {
		return Optional.ofNullable(delegateFinder.getScreenshotPathsForTestStep(key)).filter[!empty].or[
			val latestCallTree = key.deriveWithSuiteRunId.getLatestCallTree(workspace) //
			latestCallTree.map[
				callTree.getDescendantsKeys(key)[readYaml] //
					.map[delegateFinder.getScreenshotPathsForTestStep(it)] //
					.reduce[list1, list2|list1 + list2]
			]
		].orElse(#[])
	}

}
