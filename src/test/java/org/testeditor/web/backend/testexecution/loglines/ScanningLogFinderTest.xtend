package org.testeditor.web.backend.testexecution.loglines

import java.io.File
import java.nio.file.Files
import java.nio.file.Paths
import javax.inject.Provider
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Spy
import org.mockito.junit.MockitoJUnitRunner
import org.testeditor.web.backend.testexecution.TestExecutionKey
import org.testeditor.web.backend.testexecution.dropwizard.TestExecutionConfiguration
import org.testeditor.web.backend.testexecution.util.HierarchicalLineSkipper
import org.testeditor.web.backend.testexecution.util.RecursiveHierarchicalLineSkipper

import static java.nio.charset.StandardCharsets.UTF_8
import static org.assertj.core.api.Assertions.assertThat
import static org.junit.Assert.fail
import static org.mockito.ArgumentMatchers.anyString
import static org.mockito.ArgumentMatchers.eq
import static org.mockito.ArgumentMatchers.matches
import static org.mockito.Mockito.when

import static extension java.nio.file.Files.readAllLines

@RunWith(MockitoJUnitRunner)
class ScanningLogFinderTest {

	static val SAMPLE_LOG_FILE_PATH = Paths.get('src/test/resources/sample.log')
	static val TEST_SUITE_RUN_LOG_LINES = Paths.get('src/test/resources/test-suite-run-expected-result.log').readAllLines(UTF_8)
	static val TEST_SUITE_RUN_INFO_LOG_LINES = #[
		"    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase ****************************************************",
		"    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase Running test for sample.LoginTest",
		"    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase ****************************************************",
		"    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Starting browser: firefox",
		"    11:16:34 WARN  [Test worker]  [TE-Test: LoginTest] WebDriverManager Network not available. Forcing the use of cache",
		"    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Found geckodriver in cache: /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver ",
		"    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Exporting webdriver.gecko.driver as /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver",
		"    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture The file with the name browserSetup.json can not be found in the resource folder.",
		"    11:16:38 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111638.751-Start_Firefox.LEAVE.png'.",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111639.947-Browse_http_example.org.LEAVE.png'.",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111640.127-WebBrowser.LEAVE.png'.",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111640.221-_ffnen_eines_Browsers_und_auf_EXAMPLE-Test_navigieren.LEAVE.png'.",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Lookup element login-form-username type ID",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111640.485-Enter_test_into_UserName.LEAVE.png'.",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Lookup element login-form-password type ID",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111640.758-Enter_test_into_Password.LEAVE.png'.",
		"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Lookup element login type ID",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111642.902-Click_LoginButton.LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111643.056-LoginPage.LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111643.194-Einloggen_als_user_test_pwd_test.LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Lookup element //div[@id = 'dashboard']//h1 type XPATH",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111643.367-titel_Read_Header_java.lang.String.LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111643.501-assert_titel_System_Dashboard.LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111643.643-Dashboard.LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111643.788-Dashboard-Titel_sollte_System_Dashboard_sein..LEAVE.png'.",
		"    11:16:43 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Lookup element header-details-user-fullname type ID",
		"    11:16:44 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111644.232-Click_UserProfileIcon.LEAVE.png'.",
		"    11:16:44 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Lookup element log_out type ID",
		"    11:16:45 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111645.185-Click_LogoutButton.LEAVE.png'.",
		"    11:16:45 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111645.507-TopBar.LEAVE.png'.",
		"    11:16:45 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111645.655-Ausloggen_aus_EXAMPLE..LEAVE.png'.",
		"    11:16:50 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase ****************************************************",
		"    11:16:50 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase Test sample.LoginTest finished with 17 sec. duration.",
		"    11:16:50 INFO  [Test worker]  [TE-Test: LoginTest] AbstractTestCase ****************************************************"
	]
	static val TEST_SUITE_RUN_WITHOUT_SUB_STEPS_LOG_LINES = #[
		'Picked up _JAVA_OPTIONS: -Djdk.http.auth.tunneling.disabledSchemes=',
		'Gradle now uses separate output directories for each JVM language, but this build assumes a single directory for all classes from a source set. This behaviour has been deprecated and is scheduled to be removed in Gradle 5.0',
		':generateXtext NO-SOURCE',
		':compileJava',
		':processResources NO-SOURCE',
		':classes',
		':generateTestXtextWarning: NLS unused message: line_separator_platform_mac_os_9 in: org.eclipse.core.internal.runtime.messages',
		'Warning: NLS missing message: auth_alreadySpecified in: org.eclipse.core.internal.runtime.messages',
		'Warning: NLS missing message: plugin_unableToGetActivator in: org.eclipse.core.internal.runtime.messages',
		'',
		':compileTestJava',
		':processTestResources',
		':testClasses',
		':testTask1Picked up _JAVA_OPTIONS: -Djdk.http.auth.tunneling.disabledSchemes=',
		'',
		'',
		'sample.LoginTest STANDARD_ERROR',
		'    SLF4J: Class path contains multiple SLF4J bindings.',
		'    SLF4J: Found binding in [jar:file:/home/sampleUser/.gradle/caches/modules-2/files-2.1/org.apache.logging.log4j/log4j-slf4j-impl/2.5/d1e34a4525e08873703fdaad6c6284f944f8ca8f/log4j-slf4j-impl-2.5.jar!/org/slf4j/impl/StaticLoggerBinder.class]',
		'    SLF4J: Found binding in [jar:file:/home/sampleUser/.gradle/caches/modules-2/files-2.1/ch.qos.logback/logback-classic/1.2.3/7c4f3c474fb2c041d8028740440937705ebb473a/logback-classic-1.2.3.jar!/org/slf4j/impl/StaticLoggerBinder.class]',
		'    SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.',
		'    SLF4J: Actual binding is of type [org.apache.logging.slf4j.Log4jLoggerFactory]',
		'Starting test for the following test class: sample.LoginTest with id 0.0.0',
		':testSuite',
		'',
		'BUILD SUCCESSFUL in 37s',
		'5 actionable tasks: 5 executed'
	]

	@Rule public val TemporaryFolder testRoot = new TemporaryFolder

	@Mock Provider<File> mockWorkspace
	@Mock TestExecutionConfiguration mockConfig
	@Spy HierarchicalLineSkipper lineSkipper = new RecursiveHierarchicalLineSkipper
	@Mock LogFilter mockLogFilter

	@InjectMocks
	ScanningLogFinder logFinder

	// DONOT USE, introduces usage of an element used for InjectMocks but not used anywhere else, makeing the IDE report an annoying warning
	protected def dummyUsageOfInjected() {
		lineSkipper
	}

	@Test
	@Ignore
	def void shouldReturnRelevantLogLines() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'ID3')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		when(mockLogFilter.isVisibleOn(anyString, eq(LogLevel.TRACE))).thenReturn(true)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(
			#['    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Starting browser: firefox',
				'    11:16:34 WARN  [Test worker]  [TE-Test: LoginTest] WebDriverManager Network not available. Forcing the use of cache',
				'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Found geckodriver in cache: /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver ',
				'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Exporting webdriver.gecko.driver as /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver',
				'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture The file with the name browserSetup.json can not be found in the resource folder.',
				'', 'sample.LoginTest > execute STANDARD_ERROR', '    1531732594957	geckodriver	INFO	geckodriver 0.21.0',
				'    1531732594971	geckodriver	INFO	Listening on 127.0.0.1:18515',
				'    1531732595519	mozrunner::runner	INFO	Running command: "/usr/bin/firefox" "-marionette" "-foreground" "-no-remote" "-profile" "/tmp/rust_mozprofile.FqR43PRTftn3"',
				'    1531732595922	addons.xpi	WARN	Can\'t get modified time of /usr/lib64/firefox/browser/features/aushelper@mozilla.org.xpi',
				'    1531732596091	addons.xpi-utils	WARN	addMetadata: Add-on aushelper@mozilla.org is invalid: [Exception... "Component returned failure code: 0x80520006 (NS_ERROR_FILE_TARGET_DOES_NOT_EXIST) [nsIFile.isFile]"  nsresult: "0x80520006 (NS_ERROR_FILE_TARGET_DOES_NOT_EXIST)"  location: "JS frame :: resource://gre/modules/addons/XPIInstall.jsm :: this.loadManifestFromFile :: line 971"  data: no] Stack trace: this.loadManifestFromFile()@resource://gre/modules/addons/XPIInstall.jsm:971 < syncLoadManifestFromFile()@resource://gre/modules/addons/XPIProvider.jsm:947 < addMetadata()@resource://gre/modules/addons/XPIProvider.jsm -> resource://gre/modules/addons/XPIProviderUtils.js:1231 < processFileChanges()@resource://gre/modules/addons/XPIProvider.jsm -> resource://gre/modules/addons/XPIProviderUtils.js:1578 < checkForChanges()@resource://gre/modules/addons/XPIProvider.jsm:3278 < startup()@resource://gre/modules/addons/XPIProvider.jsm:2182 < callProvider()@resource://gre/modules/AddonManager.jsm:263 < _startProvider()@resource://gre/modules/AddonManager.jsm:730 < startup()@resource://gre/modules/AddonManager.jsm:897 < startup()@resource://gre/modules/AddonManager.jsm:3081 < observe()@jar:file:///usr/lib64/firefox/omni.ja!/components/addonManager.js:65',
				'    1531732596093	addons.xpi-utils	WARN	Could not uninstall invalid item from locked install location',
				'    1531732596301	Marionette	INFO	Enabled via --marionette',
				'    1531732598041	addons.xpi	WARN	Can\'t get modified time of /usr/lib64/firefox/browser/features/aushelper@mozilla.org.xpi',
				'    1531732598322	Marionette	INFO	Listening on port 42923',
				'    1531732598366	Marionette	WARN	TLS certificate errors will be ignored for this session',
				'    1531732598435	Marionette	DEBUG	Register listener.js for window 2147483649',
				'    Jul 16, 2018 11:16:38 AM org.openqa.selenium.remote.ProtocolHandshake createSession', '    INFO: Detected dialect: W3C', '',
				'sample.LoginTest > execute STANDARD_OUT',
				'    11:16:38 DEBUG [Test worker]  [TE-Test: LoginTest] WebDriverFixture Screen-Width: 1920 Screen-Height: 1080'])
	}

	@Test
	@Ignore
	def void shouldReturnRelevantLogLinesOfInfoLevelOrAbove() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'ID3')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		when(mockLogFilter.isVisibleOn(matches('^    11:16:3\\d (INFO|WARN).+'), eq(LogLevel.INFO))).thenReturn(true)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key, LogLevel.INFO)

		// then
		assertThat(actualLogLines).containsExactly(#[
			'    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Starting browser: firefox',
			'    11:16:34 WARN  [Test worker]  [TE-Test: LoginTest] WebDriverManager Network not available. Forcing the use of cache',
			'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Found geckodriver in cache: /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver ',
			'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Exporting webdriver.gecko.driver as /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver',
			'    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture The file with the name browserSetup.json can not be found in the resource folder.'
		])
	}

	@Test
	@Ignore
	def void shouldSkipLogLinesOfSubSteps() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'ID2')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		when(mockLogFilter.isVisibleOn(anyString, eq(LogLevel.TRACE))).thenReturn(true)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(
			#[
				"    11:16:38 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111638.751-Start_Firefox.LEAVE.png'.",
				"    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111639.947-Browse_http_example.org.LEAVE.png'."])
	}

	@Test
	@Ignore
	def void shouldNotSkipLogLinesOfSubStepsWhenConfiguredAccordingly() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'ID2')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(false)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		when(mockLogFilter.isVisibleOn(anyString, eq(LogLevel.TRACE))).thenReturn(true)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(#[
				'''    11:16:32 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Starting browser: firefox''', '''    11:16:34 WARN  [Test worker]  [TE-Test: LoginTest] WebDriverManager Network not available. Forcing the use of cache''', '''    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Found geckodriver in cache: /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver ''', '''    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverManager Exporting webdriver.gecko.driver as /home/sampleUser/.m2/repository/webdriver/geckodriver/linux64/0.21.0/geckodriver''', '''    11:16:34 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture The file with the name browserSetup.json can not be found in the resource folder.''', '''''', '''sample.LoginTest > execute STANDARD_ERROR''', '''    1531732594957	geckodriver	INFO	geckodriver 0.21.0''', '''    1531732594971	geckodriver	INFO	Listening on 127.0.0.1:18515''', '''    1531732595519	mozrunner::runner	INFO	Running command: "/usr/bin/firefox" "-marionette" "-foreground" "-no-remote" "-profile" "/tmp/rust_mozprofile.FqR43PRTftn3"''', '''    1531732595922	addons.xpi	WARN	Can't get modified time of /usr/lib64/firefox/browser/features/aushelper@mozilla.org.xpi''', '''    1531732596091	addons.xpi-utils	WARN	addMetadata: Add-on aushelper@mozilla.org is invalid: [Exception... "Component returned failure code: 0x80520006 (NS_ERROR_FILE_TARGET_DOES_NOT_EXIST) [nsIFile.isFile]"  nsresult: "0x80520006 (NS_ERROR_FILE_TARGET_DOES_NOT_EXIST)"  location: "JS frame :: resource://gre/modules/addons/XPIInstall.jsm :: this.loadManifestFromFile :: line 971"  data: no] Stack trace: this.loadManifestFromFile()@resource://gre/modules/addons/XPIInstall.jsm:971 < syncLoadManifestFromFile()@resource://gre/modules/addons/XPIProvider.jsm:947 < addMetadata()@resource://gre/modules/addons/XPIProvider.jsm -> resource://gre/modules/addons/XPIProviderUtils.js:1231 < processFileChanges()@resource://gre/modules/addons/XPIProvider.jsm -> resource://gre/modules/addons/XPIProviderUtils.js:1578 < checkForChanges()@resource://gre/modules/addons/XPIProvider.jsm:3278 < startup()@resource://gre/modules/addons/XPIProvider.jsm:2182 < callProvider()@resource://gre/modules/AddonManager.jsm:263 < _startProvider()@resource://gre/modules/AddonManager.jsm:730 < startup()@resource://gre/modules/AddonManager.jsm:897 < startup()@resource://gre/modules/AddonManager.jsm:3081 < observe()@jar:file:///usr/lib64/firefox/omni.ja!/components/addonManager.js:65''', '''    1531732596093	addons.xpi-utils	WARN	Could not uninstall invalid item from locked install location''', '''    1531732596301	Marionette	INFO	Enabled via --marionette''', '''    1531732598041	addons.xpi	WARN	Can't get modified time of /usr/lib64/firefox/browser/features/aushelper@mozilla.org.xpi''', '''    1531732598322	Marionette	INFO	Listening on port 42923''', '''    1531732598366	Marionette	WARN	TLS certificate errors will be ignored for this session''', '''    1531732598435	Marionette	DEBUG	Register listener.js for window 2147483649''', '''    Jul 16, 2018 11:16:38 AM org.openqa.selenium.remote.ProtocolHandshake createSession''', '''    INFO: Detected dialect: W3C''', '''''', '''sample.LoginTest > execute STANDARD_OUT''', '''    11:16:38 DEBUG [Test worker]  [TE-Test: LoginTest] WebDriverFixture Screen-Width: 1920 Screen-Height: 1080''', '''    11:16:38 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111638.751-Start_Firefox.LEAVE.png'.''', '''''', '''sample.LoginTest > execute STANDARD_ERROR''', '''    1531732598799	Marionette	DEBUG	Received DOM event "beforeunload" for "about:blank"''', '''    1531732598895	Marionette	DEBUG	Received DOM event "pagehide" for "about:blank"''', '''    1531732598896	Marionette	DEBUG	Received DOM event "unload" for "about:blank"''', '''    1531732599855	Marionette	DEBUG	Received DOM event "DOMContentLoaded" for "http://example.org/Dashboard"''', '''    1531732599938	Marionette	DEBUG	Received DOM event "pageshow" for "http://example.org/Dashboard"''', '''''', '''sample.LoginTest > execute STANDARD_OUT''', '''    11:16:40 INFO  [Test worker]  [TE-Test: LoginTest] WebDriverFixture Wrote screenshot to file='screenshots/sample.LoginTest/20180716/111639.947-Browse_http_example.org.LEAVE.png'.'''])
	}

	@Test
	def void shouldReturnEmptyListForNonExistingCallTreeId() {
		// given
		val key = new TestExecutionKey('0', '0', '0', 'non-existing-call-tree-id')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).isEmpty
	}

	@Test
	def void shouldReturnTestCaseLogForTestExecutionKeyWithoutCallTreeId() {
		// given
		val key = new TestExecutionKey('0', '0', '0')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		when(mockLogFilter.isVisibleOn(anyString, eq(LogLevel.TRACE))).thenReturn(true)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(#['', 'sample.LoginTest > execute STANDARD_OUT'])
	}

	@Test
	def void shouldThrowExceptionOnAmbiguousTestExecutionKey() {
		// given
		val key = new TestExecutionKey('0')
		val arbitraryDateAndTime = '20180716111612603'

		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		try {
			logFinder.getLogLinesForTestStep(key)
			fail('Expected exception but none was thrown.')

		// then
		} catch (IllegalArgumentException exception) {
			assertThat(exception.message).isEqualTo(
				"Provided test execution key must contain a test suite id and a test suite run id. (Key was: '0---'.)")
		}
	}

	@Test
	def void shouldThrowExceptionIfTestExecutionKeyIsNull() {
		// given
		val key = null
		val arbitraryDateAndTime = '20180716111612603'

		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		// when
		try {
			logFinder.getLogLinesForTestStep(key)
			fail('Expected exception but none was thrown.')

		// then
		} catch (NullPointerException exception) {
			assertThat(exception.message).isEqualTo(
				"Provided test execution key must contain a test suite id and a test suite run id. (Key was: 'null'.)")
		}
	}

	@Test
	def void shouldReturnTestSuiteRunLogForTestExecutionKeyWithoutTestRunId() {
		// given
		val key = new TestExecutionKey('0', '0')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(false)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		when(mockLogFilter.isVisibleOn(anyString, eq(LogLevel.TRACE))).thenReturn(true)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(TEST_SUITE_RUN_LOG_LINES)
	}

	@Test
	def void shouldReturnTestSuiteRunLogFilteredToInfoLevelForTestExecutionKeyWithoutTestRunId() {
		// given
		val key = new TestExecutionKey('0', '0')
		val arbitraryDateAndTime = '20180716111612603'
		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(false)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		when(mockLogFilter.isVisibleOn(matches('^    11:16:\\d\\d (INFO|WARN).+'), eq(LogLevel.INFO))).thenReturn(true)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key, LogLevel.INFO)

		// then
		assertThat(actualLogLines).containsExactly(TEST_SUITE_RUN_INFO_LOG_LINES)
	}

	@Test
	def void shouldReturnTestSuiteRunLogWithoutSubstepsForTestExecutionKeyWithoutTestRunId() {
		// given
		val key = new TestExecutionKey('0', '0')
		val arbitraryDateAndTime = '20180716111612603'

		when(mockConfig.filterTestSubStepsFromLogs).thenReturn(true)

		when(mockWorkspace.get).thenReturn(testRoot.root)
		val logPath = testRoot.newFolder('logs').toPath
		val logFile = logPath.resolve('''testrun.0-0--.«arbitraryDateAndTime».log''')
		Files.copy(SAMPLE_LOG_FILE_PATH, logFile)

		when(mockLogFilter.isVisibleOn(anyString, eq(LogLevel.TRACE))).thenReturn(true)

		// when
		val actualLogLines = logFinder.getLogLinesForTestStep(key)

		// then
		assertThat(actualLogLines).containsExactly(TEST_SUITE_RUN_WITHOUT_SUB_STEPS_LOG_LINES)
	}

}
