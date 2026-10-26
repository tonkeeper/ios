import AnyCodable
import Foundation

public struct EncodableUnion<Base: Encodable, Extra: Encodable>: Encodable {
    var base: Base
    var extra: Extra

    public func encode(to encoder: any Encoder) throws {
        var mergedObject = try encodeJSONObject(base, codingPath: encoder.codingPath)
        try mergedObject.merge(
            encodeJSONObject(extra, codingPath: encoder.codingPath),
            uniquingKeysWith: { _, extraValue in extraValue }
        )

        var container = encoder.singleValueContainer()
        try container.encode(mergedObject)
    }
}

public extension Encodable {
    func withExtraValues<Extra: Encodable>(_ extra: Extra) -> EncodableUnion<Self, Extra> {
        EncodableUnion(base: self, extra: extra)
    }
}

private func encodeJSONObject<Value: Encodable>(
    _ value: Value,
    codingPath: [CodingKey]
) throws -> [String: AnyEncodable] {
    let data = try JSONEncoder().encode(value)
    let jsonValue = try JSONDecoder().decode(AnyDecodable.self, from: data)

    guard let object = jsonValue.value as? [String: Any] else {
        throw EncodingError.invalidValue(
            value,
            EncodingError.Context(
                codingPath: codingPath,
                debugDescription: "EncodableUnion requires keyed JSON objects for both base and extra values."
            )
        )
    }

    return object.mapValues(AnyEncodable.init)
}
