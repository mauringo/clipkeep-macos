import Testing
@testable import ClipboardCore

struct ReleaseVersionTests {
    @Test func comparesComponentsNumerically() throws {
        #expect(try #require(ReleaseVersion("1.10.0")) > #require(ReleaseVersion("1.9.9")))
        #expect(ReleaseVersion("v1.3.0") == ReleaseVersion("1.3.0"))
        #expect(try #require(ReleaseVersion("2.0.0")) > #require(ReleaseVersion("1.99.99")))
        #expect(try #require(ReleaseVersion("1.3.1")) > #require(ReleaseVersion("1.3.0")))
    }

    @Test func rejectsPrereleasesMalformedAndOverflowingVersions() {
        for value in ["", "1.2", "1.2.3.4", "1..3", "1.2.3-beta.1", "1.2.3+build", "-1.2.3", "01.2.3", "1.2. 3", "999999999999999999999999.0.0"] {
            #expect(ReleaseVersion(value) == nil)
        }
    }
}
