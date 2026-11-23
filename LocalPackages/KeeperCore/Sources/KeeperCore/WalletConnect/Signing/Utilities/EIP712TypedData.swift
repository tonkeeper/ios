import BigInt
import Foundation
import WalletCore

/// `eth_signTypedData_v4` data by the two hashes a Ledger signs it with, encoded as MetaMask's v4 encodes it.
struct EIP712TypedData: Equatable {
    enum Failure: Error, Equatable {
        case malformed(String)
    }

    let domainSeparator: Data
    let messageHash: Data

    /// What is signed: `keccak256(0x19 ‖ 0x01 ‖ domainSeparator ‖ messageHash)`.
    var digest: Data {
        Hash.keccak256(data: Data([0x19, 0x01]) + domainSeparator + messageHash)
    }

    init(json: String) throws {
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let rawTypes = object["types"] as? [String: Any],
              let primaryType = object["primaryType"] as? String,
              let domain = object["domain"] as? [String: Any],
              let message = object["message"] as? [String: Any]
        else {
            throw Failure.malformed("not EIP-712 typed data")
        }
        guard primaryType != Self.domainType else {
            throw Failure.malformed("the primary type is the domain, which leaves no message hash")
        }
        var types = try rawTypes.mapValues(Self.fields)
        types[Self.domainType] = types[Self.domainType] ?? []
        let encoder = Encoder(types: types)
        domainSeparator = try encoder.hashStruct(Self.domainType, domain)
        messageHash = try encoder.hashStruct(primaryType, message)
    }

    private static let domainType = "EIP712Domain"

    private static func fields(_ value: Any) throws -> [Encoder.Field] {
        guard let fields = value as? [[String: Any]] else {
            throw Failure.malformed("a type is not a list of fields")
        }
        return try fields.map { field in
            guard let name = field["name"] as? String, let type = field["type"] as? String else {
                throw Failure.malformed("a field has no name or type")
            }
            return Encoder.Field(name: name, type: type)
        }
    }
}

private struct Encoder {
    struct Field {
        let name: String
        let type: String
    }

    let types: [String: [Field]]

    func hashStruct(_ type: String, _ value: [String: Any]) throws -> Data {
        try Hash.keccak256(data: encodeData(type, value))
    }

    private func encodeData(_ type: String, _ value: [String: Any]) throws -> Data {
        guard let fields = types[type] else {
            throw EIP712TypedData.Failure.malformed("unknown type \(type)")
        }
        var data = try Hash.keccak256(data: Data(encodeType(type).utf8))
        for field in fields {
            try data.append(encodeField(field.type, value[field.name]))
        }
        return data
    }

    /// The type and every struct it refers to, the others sorted by name: `Mail(Person from,…)Person(…)`.
    private func encodeType(_ type: String) throws -> String {
        let dependencies = dependencies(of: type, found: []).subtracting([type]).sorted()
        return try ([type] + dependencies).map { name in
            guard let fields = types[name] else {
                throw EIP712TypedData.Failure.malformed("unknown type \(name)")
            }
            return "\(name)(\(fields.map { "\($0.type) \($0.name)" }.joined(separator: ",")))"
        }.joined()
    }

    private func dependencies(of type: String, found: Set<String>) -> Set<String> {
        let name = String(type.prefix { $0.isLetter || $0.isNumber || $0 == "_" })
        guard !found.contains(name), let fields = types[name] else {
            return found
        }
        return fields.reduce(found.union([name])) { dependencies(of: $1.type, found: $0) }
    }

    /// One 32-byte word: a value of an atomic type, or the hash of anything longer.
    private func encodeField(_ type: String, _ value: Any?) throws -> Data {
        let value = value is NSNull ? nil : value
        if types[type] != nil {
            guard let value else {
                return Data(count: 32)
            }
            guard let object = value as? [String: Any] else {
                throw EIP712TypedData.Failure.malformed("\(type) is not an object")
            }
            return try hashStruct(type, object)
        }
        guard let value else {
            throw EIP712TypedData.Failure.malformed("a \(type) field has no value")
        }
        if type.hasSuffix("]") {
            guard let items = value as? [Any], let open = type.lastIndex(of: "[") else {
                throw EIP712TypedData.Failure.malformed("\(type) is not a list")
            }
            let itemType = String(type[..<open])
            return try Hash.keccak256(data: items.reduce(Data()) { try $0 + encodeField(itemType, $1) })
        }
        switch type {
        case "string":
            guard let string = value as? String else {
                throw EIP712TypedData.Failure.malformed("a string field is not a string")
            }
            return Hash.keccak256(data: Data(string.utf8))
        case "bytes":
            return try Hash.keccak256(data: bytes(value))
        case "bool":
            guard let bool = value as? Bool else {
                throw EIP712TypedData.Failure.malformed("a bool field is not a bool")
            }
            return word(BigUInt(bool ? 1 : 0))
        case "address":
            let address = try bytes(value)
            guard address.count == 20 else {
                throw EIP712TypedData.Failure.malformed("an address field is not 20 bytes")
            }
            return Data(count: 12) + address
        case _ where type.hasPrefix("bytes"):
            let fixed = try bytes(value)
            guard let size = Int(type.dropFirst(5)), (1 ... 32).contains(size), fixed.count <= size else {
                throw EIP712TypedData.Failure.malformed("a \(type) field does not fit its size")
            }
            return fixed + Data(count: 32 - fixed.count)
        case _ where type.hasPrefix("uint") || type.hasPrefix("int"):
            let number = try integer(value)
            guard number.bitWidth <= 257 else {
                throw EIP712TypedData.Failure.malformed("a \(type) field does not fit 256 bits")
            }
            return word(number.sign == .minus ? (BigUInt(1) << 256) - number.magnitude : number.magnitude)
        default:
            throw EIP712TypedData.Failure.malformed("unsupported type \(type)")
        }
    }

    private func word(_ value: BigUInt) -> Data {
        let bytes = value.serialize()
        return Data(count: max(0, 32 - bytes.count)) + bytes.suffix(32)
    }

    private func bytes(_ value: Any) throws -> Data {
        guard let string = value as? String else {
            throw EIP712TypedData.Failure.malformed("a bytes field is not a string")
        }
        guard string.hasPrefix("0x") else {
            return Data(string.utf8)
        }
        let hex = String(string.dropFirst(2))
        guard let data = Data(hexString: hex.count % 2 == 0 ? hex : "0" + hex) else {
            throw EIP712TypedData.Failure.malformed("a bytes field is not hex")
        }
        return data
    }

    private func integer(_ value: Any) throws -> BigInt {
        let text: String
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            text = number.stringValue
        } else if let string = value as? String {
            text = string
        } else {
            throw EIP712TypedData.Failure.malformed("a number field is not a number")
        }
        let isNegative = text.hasPrefix("-")
        let digits = isNegative ? String(text.dropFirst()) : text
        let magnitude = digits.lowercased().hasPrefix("0x") ? BigUInt(String(digits.dropFirst(2)), radix: 16) : BigUInt(digits, radix: 10)
        guard let magnitude else {
            throw EIP712TypedData.Failure.malformed("\(text) is not an integer")
        }
        return isNegative ? -BigInt(magnitude) : BigInt(magnitude)
    }
}
