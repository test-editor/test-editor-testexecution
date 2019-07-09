package org.testeditor.web.backend.testexecution

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
class TestSuiteStatusInfo {

	var TestExecutionKey key
	var String status

}
