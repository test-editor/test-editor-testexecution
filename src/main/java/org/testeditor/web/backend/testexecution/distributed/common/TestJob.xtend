package org.testeditor.web.backend.testexecution.distributed.common

import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonProperty
import java.util.ArrayList
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.testeditor.web.backend.testexecution.common.TestExecutionKey
import org.testeditor.web.backend.testexecution.common.TestStatus

import static org.testeditor.web.backend.testexecution.common.TestStatus.*

interface TestJobInfo {
	def TestExecutionKey getId()
	def Set<String> getRequiredCapabilities()
	def List<String> getResourcePaths()
	def JobState getState()
	def TestJobInfo setState(JobState state)
	
	enum JobState {

		PENDING,
		ASSIGNING,
		ASSIGNED,
		COMPLETED_SUCCESSFULLY,
		COMPLETED_WITH_ERROR,
		COMPLETED_CANCELLED

	}
	
	def TestStatus testStatus() {
		return switch(state) {
			case PENDING, case ASSIGNING: IDLE
			case ASSIGNED: RUNNING
			case COMPLETED_SUCCESSFULLY: SUCCESS
			case COMPLETED_WITH_ERROR, case COMPLETED_CANCELLED: FAILED
		}
	}
}

@EqualsHashCode
@Data
class TestJob implements TestJobInfo {

	public static val TestJob NONE = new TestJob(new TestExecutionKey(''), emptySet, emptyList)

	val TestExecutionKey id
	val Set<String> requiredCapabilities
	val List<String> resourcePaths
	@Accessors(PUBLIC_GETTER)
	transient val JobState state

	@JsonCreator
	new(@JsonProperty('id') TestExecutionKey id, @JsonProperty('requiredCapabilities') Set<String> capabilities, @JsonProperty('resourcePaths') Iterable<String> resourcePaths) {
		this(id, new HashSet(capabilities), resourcePaths, JobState.PENDING)
	}
	
	private new(TestExecutionKey id, Set<String> capabilities, Iterable<String> resourcePaths, JobState state) {
		this.id = id
		this.requiredCapabilities = new HashSet(capabilities)
		this.resourcePaths = new ArrayList => [addAll(resourcePaths)]
		this.state = state
	}
	
	override TestJobInfo setState(JobState state) {
		return new TestJob(this.id, this.requiredCapabilities, this.resourcePaths, state)
	}

}
