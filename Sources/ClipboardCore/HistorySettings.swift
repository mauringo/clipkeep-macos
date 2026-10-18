import Foundation

public struct HistorySettings: Equatable {
    public static let allowedLimits = 1...1_000
    public let maximumEntries: Int
    public let keepAfterRestart: Bool

    public init(maximumEntries: Int = 100, keepAfterRestart: Bool = true) {
        self.maximumEntries = min(max(maximumEntries, Self.allowedLimits.lowerBound), Self.allowedLimits.upperBound)
        self.keepAfterRestart = keepAfterRestart
    }

    public static func load(from defaults: UserDefaults = .standard) -> HistorySettings {
        HistorySettings(
            maximumEntries: defaults.object(forKey: "maximumHistoryEntries") == nil
                ? 100 : defaults.integer(forKey: "maximumHistoryEntries"),
            keepAfterRestart: defaults.object(forKey: "keepHistoryAfterRestart") == nil
                ? true : defaults.bool(forKey: "keepHistoryAfterRestart"))
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(maximumEntries, forKey: "maximumHistoryEntries")
        defaults.set(keepAfterRestart, forKey: "keepHistoryAfterRestart")
    }
}
