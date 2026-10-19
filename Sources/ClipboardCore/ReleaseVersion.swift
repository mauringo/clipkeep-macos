import Foundation

/// Stable three-component release versions. Prereleases are deliberately excluded.
public struct ReleaseVersion: Comparable, Sendable {
    private let components: [Int]

    public init?(_ string: String) {
        let value = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int(part), part.count == 1 || !part.hasPrefix("0") else { return nil }
            numbers.append(number)
        }
        components = numbers
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}
