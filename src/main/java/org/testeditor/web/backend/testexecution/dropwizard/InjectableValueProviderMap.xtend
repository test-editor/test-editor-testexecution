package org.testeditor.web.backend.testexecution.dropwizard

import com.fasterxml.jackson.databind.BeanProperty
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.InjectableValues
import com.fasterxml.jackson.databind.JsonMappingException
import java.util.Map
import javax.inject.Provider
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
class InjectableValueProviderMap extends InjectableValues {

	val Map<String, Provider<?>> values

	override findInjectableValue(Object valueId, DeserializationContext ctxt, BeanProperty forProperty,
		Object beanInstance) throws JsonMappingException {
		return values.get(valueId)?.get
	}

}
