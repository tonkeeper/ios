import BigInt

struct DirtyBigInt: Decodable {
    var bigIntValue: BigInt

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            bigIntValue = try BigInt(
                container.decode(Int64.self)
            )
        } catch {
            do {
                bigIntValue = try BigInt(
                    container.decode(UInt64.self)
                )
            } catch {
                let stringValue = try container.decode(String.self)
                let bigIntFromString = try BigInt(
                    container.decode(String.self)
                )
                guard let bigIntFromString else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "failed to create bigint from \(stringValue)"
                    )
                }
                bigIntValue = bigIntFromString
            }
        }
    }
}
