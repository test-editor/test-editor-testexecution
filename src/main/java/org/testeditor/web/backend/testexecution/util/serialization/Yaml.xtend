package org.testeditor.web.backend.testexecution.util.serialization

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import java.io.File
import java.util.Map
import javax.inject.Singleton

interface YamlReader {
	def Map<String, Object> readYaml(String yaml)
	def Map<String, Object> readYaml(File yaml)
}

@Singleton
class Yaml implements YamlReader {
	val objectMapper = new ObjectMapper(new YAMLFactory)
	
	override readYaml(String yaml) {
		return objectMapper.readValue(yaml, Map)
	}
	
	override readYaml(File yaml) {
		return objectMapper.readValue(yaml, Map)
	}
	
}