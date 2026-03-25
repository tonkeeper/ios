import Foundation
import TonAPI

public protocol JSONEncodable {
    func encodeToJSON() -> Any
}

public extension JSONEncodable where Self: Encodable {
    func encodeToJSON() -> Any {
        guard let data = try? CodableHelper.jsonEncoder.encode(self) else {
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
