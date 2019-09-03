package org.testeditor.web.backend.testexecution.manager

import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonProperty
import java.util.ArrayList
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.testeditor.web.backend.testexecution.TestExecutionKey

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
		COMPLETED

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
	new(@JsonProperty('id') TestExecutionKey id, @JsonProperty('requiredCapabilities') Set<String> capabilities, @JsonProperty('resourcePaths') List<String> resourcePaths) {
		this(id, new HashSet(capabilities), new ArrayList(resourcePaths), JobState.PENDING)
	}
	
	private new(TestExecutionKey id, Set<String> capabilities, List<String> resourcePaths, JobState state) {
		this.id = id
		this.requiredCapabilities = new HashSet(capabilities)
		this.resourcePaths = new ArrayList(resourcePaths)
		this.state = state
	}
	
	override TestJobInfo setState(JobState state) {
		return new TestJob(this.id, this.requiredCapabilities, this.resourcePaths, state)
	}

}
