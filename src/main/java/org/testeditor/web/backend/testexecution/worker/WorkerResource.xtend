package org.testeditor.web.backend.testexecution.worker

import javax.ws.rs.DELETE
import javax.ws.rs.GET
import javax.ws.rs.PUT
import javax.ws.rs.Path
import org.testeditor.web.backend.testexecution.manager.TestJob

@Path('/worker')
class WorkerResource {
    
    @GET
    def Worker getWorkerState() {
        
    }
    
    @GET
    @Path('capabilities')
    def WorkerCapabilities getWorkerCapabilities() {
        
    }
    
    @GET
    @Path('job')
    def TestJob getTestJobState() {
        
    }
    
    @PUT
    def Worker executeTestJob() {
        
    }
    
    @DELETE
    def Worker cancelTestJob() {
        
    }
}