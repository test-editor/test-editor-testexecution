package org.testeditor.web.backend.testexecution.dropwizard

class Main {

	def static void main(String[] args) {
		if (args.head == 'worker') {
			new WorkerApplication().run(args.tail)
		} else {
			new TestExecutionApplication().run(args)
		}
	}

}
