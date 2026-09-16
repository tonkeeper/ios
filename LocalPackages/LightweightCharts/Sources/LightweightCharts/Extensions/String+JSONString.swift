import Foundation

extension String {
    /// Returns a JSON-encoded string representation.
    ///
    /// This method escapes special characters for JSON compatibility,
    /// including quotes, backslashes, and control characters.
    ///
    /// - Returns: A JSON-encoded string with quotes and proper escaping.
    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }

        return jsonString
    }
}
