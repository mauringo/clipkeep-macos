import Foundation
import Yams

/// Formatting affects only the preview. ClipboardEntry retains the original bytes.
public struct TextPresentation {
    public enum Format: String { case text = "Text", json = "JSON", yaml = "YAML" }
    public let original: String
    public let formatted: String
    public let format: Format

    public init(_ text: String) {
        original = text
        if let data = text.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object,
                options: [.prettyPrinted, .withoutEscapingSlashes]),
           let output = String(data: pretty, encoding: .utf8) {
            formatted = output
            format = .json
        } else if let output = Self.prettyYAML(text) {
            formatted = output
            format = .yaml
        } else {
            formatted = text
            format = .text
        }
    }

    private static func prettyYAML(_ text: String) -> String? {
        do {
            var stream = try Yams.compose_all(yaml: text)
            var nodes: [Node] = []
            while let node = stream.next() { nodes.append(try blockStyle(node)) }
            guard stream.error == nil, !nodes.isEmpty,
                  nodes.contains(where: { $0.mapping != nil || $0.sequence != nil }) else { return nil }
            return try Yams.serialize(nodes: nodes, indent: 2, width: 100,
                                      allowUnicode: true, explicitStart: nodes.count > 1)
        } catch { return nil }
    }

    private static func blockStyle(_ node: Node, depth: Int = 0) throws -> Node {
        // Avoid exhausting the stack on pathological clipboard input.
        guard depth < 128 else { throw FormattingError.tooDeep }
        switch node {
        case .mapping(var mapping):
            mapping.style = .block
            for index in mapping.indices {
                let pair = mapping[index]
                mapping[index] = (try blockStyle(pair.key, depth: depth + 1),
                                  try blockStyle(pair.value, depth: depth + 1))
            }
            return .mapping(mapping)
        case .sequence(var sequence):
            sequence.style = .block
            for index in sequence.indices { sequence[index] = try blockStyle(sequence[index], depth: depth + 1) }
            return .sequence(sequence)
        default: return node
        }
    }

    private enum FormattingError: Error { case tooDeep }
}
