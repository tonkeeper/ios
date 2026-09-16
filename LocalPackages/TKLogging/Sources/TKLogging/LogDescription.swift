import Foundation

/// Builds the `key=value, key=value` shape every `LoggableError` renders into.
public struct LogDescription {
    private var parts: [String]

    public init(type: Any.Type) {
        self.init(type: String(reflecting: type))
    }

    public init(type: String) {
        parts = ["type=\(type)"]
    }

    public func with(_ key: String, _ value: String?, limit: Int = LogDescription.defaultValueLimit) -> Self {
        guard let value, !value.isEmpty else {
            return self
        }
        var copy = self
        copy.parts.append("\(key)=\(Self.truncated(value, limit: limit))")
        return copy
    }

    public func with(_ key: String, _ value: some BinaryInteger) -> Self {
        with(key, "\(value)")
    }

    public func with(_ key: String, error: (any Error)?) -> Self {
        guard let error else {
            return self
        }
        var copy = self
        copy.parts.append("\(key)=[\(error.logDescription)]")
        return copy
    }

    public var text: String {
        parts.joined(separator: ", ")
    }

    public static let defaultValueLimit = 256

    public static func truncated(_ value: String, limit: Int) -> String {
        let limit = max(0, limit)
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else {
            return normalized
        }
        return "\(normalized.prefix(limit))…(\(normalized.count) chars)"
    }
}
