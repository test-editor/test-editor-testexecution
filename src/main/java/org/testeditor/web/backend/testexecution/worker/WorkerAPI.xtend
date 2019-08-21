package org.testeditor.web.backend.testexecution.worker

import org.testeditor.web.backend.testexecution.manager.TestJob

interface WorkerAPI {
    def Worker executeTestJob(TestJob job)
}