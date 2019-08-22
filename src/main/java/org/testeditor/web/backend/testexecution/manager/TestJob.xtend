package org.testeditor.web.backend.testexecution.manager

import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
class TestJob {
    public static val TestJob NONE = new TestJob => [id = ''; status = -1]
    
    String id
    int status
    Set<String> capabilities
    List<String> resourcePaths
	
	def TestJob copy() {
		return new TestJob => [
			it.id = this.id
			it.status = this.status
			it.capabilities = this.capabilities === null ? null : new HashSet(this.capabilities)
		]
	}
	
}
