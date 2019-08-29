package org.testeditor.web.backend.testexecution.manager

import java.net.URI
import javax.ws.rs.core.UriInfo

/**
 * Allows to append a path string to an existing URI (from the context).
 * The main purpose for this is to ease mocking: tests can mock out our own UriAppender interface, instead of the third-party UriInfo class. 
 */
interface UriAppender {
	def URI append(UriInfo uriInfo, String path)
}

class DefaultUriAppender implements UriAppender{

	override append(UriInfo uriInfo, String toAppend) {
		return uriInfo.absolutePathBuilder.path(toAppend).build()
	}
	
}