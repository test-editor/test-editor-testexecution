package org.testeditor.web.backend.testexecution.worker

import org.eclipse.xtend.lib.annotations.Data
import org.testeditor.web.backend.testexecution.manager.TestJob

@Data
class Worker {
    WorkerCapabilities capabilities
    TestJob job
}