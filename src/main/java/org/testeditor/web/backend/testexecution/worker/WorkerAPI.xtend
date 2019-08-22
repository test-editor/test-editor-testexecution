package org.testeditor.web.backend.testexecution.worker

import org.testeditor.web.backend.testexecution.manager.TestJob
import javax.ws.rs.core.Response

interface WorkerAPI {
    def Response executeTestJob(TestJob job)
}