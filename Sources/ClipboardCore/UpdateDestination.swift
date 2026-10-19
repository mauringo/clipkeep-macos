import Foundation

/// Keep writable installations in place; relocate downloaded or protected copies.
public enum UpdateDestination {
    public static func resolve(appURL: URL, parentIsWritable: Bool, homeDirectory: URL) -> URL {
        if appURL.lastPathComponent == "Clipboard Assistant.app",
           parentIsWritable,
           !appURL.pathComponents.contains("AppTranslocation") {
            return appURL
        }
        return homeDirectory.appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("Clipboard Assistant.app", isDirectory: true)
    }
}
