package org.testeditor.web.backend.testexecution.manager

import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class TestJob {
    public static val TestJob NONE = new TestJob => [id = ''; status = -1]
    
    String id
    int status
}
