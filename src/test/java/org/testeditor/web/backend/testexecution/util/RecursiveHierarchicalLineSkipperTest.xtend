package org.testeditor.web.backend.testexecution.util

import java.util.function.Function
import java.util.regex.Pattern
import org.junit.Test
import org.testeditor.web.backend.testexecution.util.HierarchicalLineSkipper.EndMarkerRequest

import static org.assertj.core.api.Assertions.*

class RecursiveHierarchicalLineSkipperTest {

	@Test
	def void shouldSkipLinesBetweenMarkers() {
		// given
		val lineSkipperUnderTest = new RecursiveHierarchicalLineSkipper

		val lines = #['first line', '@BEGIN ID1', 'second line', '@END ID1', 'third line']
		val startRegex = Pattern.compile('@BEGIN (ID[0-9]+)')
		val Function<EndMarkerRequest, Pattern> endRegexProvider = [
			Pattern.compile('''@END «IF generic»\w+«ELSE»«matcher.group(1)»«ENDIF»''')
		]

		// when
		val actualResult = lineSkipperUnderTest.skipChildren(lines, startRegex, endRegexProvider)

		// then
		assertThat(actualResult).containsExactly('first line', 'third line')
	}

	@Test
	def void shouldSkipLinesBetweenMarkersWithNestedRanges() {
		// given
		val lineSkipperUnderTest = new RecursiveHierarchicalLineSkipper

		val lines = #['first line', '@BEGIN ID1', 'second line', //
		'@BEGIN ID2', 'third line', '@END ID2', //
		'fourth line', '@END ID1', 'fifth line']
		val startRegex = Pattern.compile('@BEGIN (ID[0-9]+)')
		val Function<EndMarkerRequest, Pattern> endRegexProvider = [
			Pattern.compile('''@END «IF generic»\w+«ELSE»«matcher.group(1)»«ENDIF»''')
		]

		// when
		val actualResult = lineSkipperUnderTest.skipChildren(lines, startRegex, endRegexProvider)

		// then
		assertThat(actualResult).containsExactly('first line', 'fifth line')
	}

	@Test
	def void shouldSkipAllRemainingLinesIfNoEndMarkerExists() {
		// given
		val lineSkipperUnderTest = new RecursiveHierarchicalLineSkipper

		val lines = #['first line', '@BEGIN ID1', 'second line', 'third line']
		val startRegex = Pattern.compile('@BEGIN (ID[0-9]+)')
		val Function<EndMarkerRequest, Pattern> endRegexProvider = [
			Pattern.compile('''@END «IF generic»\w+«ELSE»«matcher.group(1)»«ENDIF»''')
		]

		// when
		val actualResult = lineSkipperUnderTest.skipChildren(lines, startRegex, endRegexProvider)

		// then
		assertThat(actualResult).containsOnly('first line')
	}

	@Test
	def void shouldSkipEndMarkerWithNoStartMarker() {
		// given
		val lineSkipperUnderTest = new RecursiveHierarchicalLineSkipper

		val lines = #['first line', 'second line', 'third line', '@END ID1']
		val startRegex = Pattern.compile('@BEGIN (ID[0-9]+)')
		val Function<EndMarkerRequest, Pattern> endRegexProvider = [
			Pattern.compile('''@END «IF generic»\w+«ELSE»«matcher.group(1)»«ENDIF»''')
		]

		// when
		val actualResult = lineSkipperUnderTest.skipChildren(lines, startRegex, endRegexProvider)

		// then
		assertThat(actualResult).containsExactly('first line', 'second line', 'third line')
	}

	@Test
	def void shouldSkipAllMarkersEvenIfInputIsNotWellFormed() {
		// given
		val lineSkipperUnderTest = new RecursiveHierarchicalLineSkipper

		val lines = #['first line', '@BEGIN ID1', 'second line', //
		'@BEGIN ID2', 'third line', '@END ID1', //
		'fourth line', '@END ID2', 'fifth line']
		val startRegex = Pattern.compile('@BEGIN (ID[0-9]+)')
		val Function<EndMarkerRequest, Pattern> endRegexProvider = [
			Pattern.compile('''@END «IF generic»\w+«ELSE»«matcher.group(1)»«ENDIF»''')
		]

		// when
		val actualResult = lineSkipperUnderTest.skipChildren(lines, startRegex, endRegexProvider)

		// then
		assertThat(actualResult).containsExactly('first line', 'fourth line', 'fifth line')
	}

	@Test
	def void shouldReturnEmptyCollectionIfInputIsEmpty() {
		// given
		val lineSkipperUnderTest = new RecursiveHierarchicalLineSkipper

		val lines = #[]
		val startRegex = Pattern.compile('@BEGIN (ID[0-9]+)')
		val Function<EndMarkerRequest, Pattern> endRegexProvider = [
			Pattern.compile('''@END «IF generic»\w+«ELSE»«matcher.group(1)»«ENDIF»''')
		]

		// when
		val actualResult = lineSkipperUnderTest.skipChildren(lines, startRegex, endRegexProvider)

		// then
		assertThat(actualResult).isEmpty
	}

}
