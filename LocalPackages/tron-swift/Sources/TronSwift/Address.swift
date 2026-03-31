import Foundation
import TKCryptoKit

public struct Address: Sendable {
    public enum ValidationError: Swift.Error {
        case prefixInvalid
        case addressLengthInvalid
        case checksumInvalid
    }

    public let raw: Data
    public let base58: String

    public init(raw: Data) throws {
        var resultRaw = raw
        if raw.count == 20 {
            resultRaw = [0x41] + raw
        }
        try Address.validate(data: resultRaw)
        self.raw = resultRaw
        self.base58 = Address.base58FromRawData(raw)
    }

    public init(address: String) throws {
        let decoded = address.decodeBase58
        guard decoded.count >= 4 else { throw ValidationError.addressLengthInvalid }
        let checksum = decoded.suffix(4)
        let hex = Data(decoded[0 ..< (decoded.count - 4)])
        let hashedChecksum = SHA256.hash(data: SHA256.hash(data: hex)).prefix(4)
        guard hashedChecksum == checksum else { throw ValidationError.checksumInvalid }
        try self.init(raw: hex)
    }

    public func notPrefixed() -> Data {
        raw.suffix(from: 1)
    }

    public var shortBase58: String {
        let leftPart = base58.prefix(7)
        let rightPart = base58.suffix(7)
        return "\(leftPart)...\(rightPart)"
    }

    private static func base58FromRawData(_ rawData: Data) -> String {
        let checksum = SHA256.hash(data: SHA256.hash(data: rawData)).prefix(4)
        return (rawData + checksum).encodeBase58
    }

    private static func validate(data: Data) throws {
        guard data[0] == 0x41 else {
            throw ValidationError.prefixInvalid
        }
        guard data.count == 21 else {
            throw ValidationError.addressLengthInvalid
        }
    }
}

extension Address: Equatable {
    public static func == (lhs: Address, rhs: Address) -> Bool {
        lhs.raw == rhs.raw
    }
}

extension Address: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw)
    }
}

extension Address: Codable {
    enum CodingKeys: CodingKey {
        case raw
        case base58
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.raw = try container.decode(Data.self, forKey: .raw)
        self.base58 = try container.decode(String.self, forKey: .base58)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.raw, forKey: .raw)
        try container.encode(self.base58, forKey: .base58)
    }
}
