import Foundation

public protocol JSONEncodable {
    func encodeToJSON() -> Any
}

public extension JSONEncodable where Self: Encodable {
    func encodeToJSON() -> Any {
        guard let data = try? analyticsJSONEncoder.encode(self) else {
            fatalError("Could not encode to json: \(self)")
        }
        return data.encodeToJSON()
    }
}

extension Data: JSONEncodable {
    public func encodeToJSON() -> Any {
        return self.base64EncodedString(options: Data.Base64EncodingOptions())
    }
}

public struct StringRule {
    public var minLength: Int?
    public var maxLength: Int?
    public var pattern: String?
}

public struct ArrayRule {
    public var minItems: Int?
    public var maxItems: Int?
    public var uniqueItems: Bool
}

private let analyticsJSONEncoder: JSONEncoder = {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .iso8601)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .formatted(dateFormatter)
    encoder.outputFormatting = .prettyPrinted
    return encoder
}()
