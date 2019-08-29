package org.testeditor.web.backend.testexecution.manager

import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonProperty
import java.util.ArrayList
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.eclipse.xtend.lib.annotations.Accessors

@EqualsHashCode
@Data
class TestJob {

	enum JobState {

		PENDING,
		ASSIGNING,
		ASSIGNED,
		COMPLETED

	}

	public static val TestJob NONE = new TestJob(new TestExecutionKey(''), emptySet, emptyList)

	val TestExecutionKey id
	val Set<String> capabilities
	val List<String> resourcePaths
	@Accessors(PUBLIC_GETTER)
	transient val JobState state

	@JsonCreator
	new(@JsonProperty('id') TestExecutionKey id, @JsonProperty('capabilities') Set<String> capabilities, @JsonProperty('resourcePaths') List<String> resourcePaths) {
		this(id, new HashSet(capabilities), new ArrayList(resourcePaths), JobState.PENDING)
	}
	
	private new(TestExecutionKey id, Set<String> capabilities, List<String> resourcePaths, JobState state) {
		this.id = id
		this.capabilities = new HashSet(capabilities)
		this.resourcePaths = new ArrayList(resourcePaths)
		this.state = state
	}
	
	def TestJob setState(JobState state) {
		return new TestJob(this.id, this.capabilities, this.resourcePaths, state)
	}

}
