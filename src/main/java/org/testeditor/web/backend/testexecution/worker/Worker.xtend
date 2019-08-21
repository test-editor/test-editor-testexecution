package org.testeditor.web.backend.testexecution.worker

import java.net.URL
import java.util.HashSet
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.testeditor.web.backend.testexecution.manager.TestJob

@Accessors
class Worker {
	URL url
    Set<String> capabilities
    TestJob job
    
    new() {}
    
    def Worker copy() {
    	return new Worker => [
    		it.url = this.url
    		it.capabilities = this.capabilities === null ? null : new HashSet(this.capabilities)
    		it.job = this.job?.copy
    	]
    }
}