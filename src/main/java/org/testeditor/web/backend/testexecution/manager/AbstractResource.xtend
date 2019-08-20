package org.testeditor.web.backend.testexecution.manager

import java.net.URI
import javax.ws.rs.core.Context
import javax.ws.rs.core.UriInfo

abstract class AbstractResource {

	@Context
	protected UriInfo uriInfo

	protected val extension UriAppender uriAppender

	new() {
		this([uriInfo, toAppend | uriInfo.absolutePathBuilder.path(toAppend).build()])
	}

	new(UriAppender uriAppender) {
		this.uriAppender = uriAppender
	}

}

interface UriAppender {
	def URI append(UriInfo uriInfo, String path)
}