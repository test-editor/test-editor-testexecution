package org.testeditor.web.backend.testexecution.util.serialization

import com.fasterxml.jackson.databind.ObjectMapper
import javax.inject.Singleton

interface JsonWriter {
	def String writeJson(Object object)
}

@Singleton
class Json implements JsonWriter {
	val objectMapper = new ObjectMapper()
	
	override writeJson(Object object) {
			return objectMapper.writeValueAsString(object)
	}
}