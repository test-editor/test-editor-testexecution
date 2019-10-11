package org.testeditor.web.backend.testexecution

import org.eclipse.xtend.lib.annotations.Accessors
import org.testeditor.web.backend.testexecution.common.TestExecutionKey

class TestExecutionException extends RuntimeException {

	@Accessors(PUBLIC_GETTER)
	val TestExecutionKey key

	new(String message, Throwable cause, TestExecutionKey key) {
		super(message, cause)
		this.key = key
	}

	override String toString() {
		return '''«message». Reason: «cause?.message». [«key»]'''
	}

}


