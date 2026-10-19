import Foundation
import Testing
@testable import ClipboardCore

struct UpdateDestinationTests {
    private let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

    @Test func writableInstalledAppUpdatesInPlace() {
        let app = URL(fileURLWithPath: "/Applications/Clipboard Assistant.app")
        #expect(UpdateDestination.resolve(appURL: app, parentIsWritable: true, homeDirectory: home) == app)
    }

    @Test func protectedRenamedAndTranslocatedAppsUseUserApplications() {
        let expected = home.appendingPathComponent("Applications/Clipboard Assistant.app", isDirectory: true)
        for (path, writable) in [
            ("/Applications/Clipboard Assistant.app", false),
            ("/Users/example/Downloads/Clipboard Assistant 2.app", true),
            ("/private/var/folders/test/AppTranslocation/id/d/Clipboard Assistant.app", false),
            ("/private/var/folders/test/AppTranslocation/id/d/Clipboard Assistant.app", true)
        ] {
            #expect(UpdateDestination.resolve(appURL: URL(fileURLWithPath: path),
                parentIsWritable: writable, homeDirectory: home) == expected)
        }
    }
}
