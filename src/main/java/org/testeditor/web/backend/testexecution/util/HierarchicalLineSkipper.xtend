package org.testeditor.web.backend.testexecution.util

import java.util.function.Function
import java.util.regex.Matcher
import java.util.regex.Pattern
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

interface HierarchicalLineSkipper {

	/**
	 * Iterates the provided strings and skips over ranges that are enclosed in
	 * strings matching the given regular expressions.
	 * 
	 * Elements that mark the beginning or end of ranges to be skipped are
	 * themselves removed, as well.
	 * 
	 * @param lines the ordered collection of strings to process
	 * @param startMarker a regular expression marking the beginning of a range
	 * to be skipped.
	 * @param endMarkerProvider a function that derives a regular expression,
	 * whose matches mark the end of a range to be skipped, from a matcher that
	 * matched a start marker. The matcher is contained in a
	 * {@link EndMarkerRequest} object. If {@link EndMarkerRequest#isGeneric}
	 * returns <code>true</code>, a regular expression should be returned that
	 * matches against any end markers, regardless of any particular start
	 * marker it may belong to.
	 * @return the collection of strings in the original order, with all marked
	 * ranges, including the markers themselves, removed.
	 */
	def Iterable<String> skipChildren(Iterable<String> lines, Pattern startMarker, Function<EndMarkerRequest, Pattern> endMarkerProvider)

	@FinalFieldsConstructor
	@Accessors
	static class EndMarkerRequest {

		val Matcher matcher

		static def EndMarkerRequest from(Matcher matcher) {
			return new EndMarkerRequest(matcher)
		}

		static def EndMarkerRequest generic() {
			return new EndMarkerRequest(null)
		}

		def boolean isGeneric() {
			return matcher === null
		}

	}

}
