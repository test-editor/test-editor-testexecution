package org.testeditor.web.backend.testexecution.util

import java.util.function.Function
import java.util.regex.Matcher
import java.util.regex.Pattern
import org.eclipse.xtend.lib.annotations.Accessors

import static org.testeditor.web.backend.testexecution.util.HierarchicalLineSkipper.EndMarkerRequest.*

class RecursiveHierarchicalLineSkipper implements HierarchicalLineSkipper {

	override skipChildren(Iterable<String> lines, Pattern startMarker, Function<EndMarkerRequest, Pattern> endMarkerProvider) {
		return if (lines.size > 0) {
			(new Context => [
				val retained = lines.takeWhile [ line |
					!(matcher = startMarker.matcher(line)).find
				].filter[!endMarkerProvider.apply(generic).matcher(it).find]

				result = retained + lines.drop(retained.size + 1) //
				.dropWhile[line|!endMarkerProvider.apply(from(matcher)).matcher(line).find].drop(1) //
				.skipChildren(startMarker, endMarkerProvider)
			]).result
		} else {
			lines
		}
	}

	@Accessors
	static class Context {

		var Matcher matcher
		var Iterable<String> result

	}

}
