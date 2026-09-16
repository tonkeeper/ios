import BigInt
import Foundation

public struct WalletConnectEVMTransaction: Sendable, Equatable {
    public var from: String?
    public var to: String?
    public var data: String
    public var value: String
    public var nonce: String?
    public var gas: String?
    public var gasPrice: String?
    public var maxFeePerGas: String?
    public var maxPriorityFeePerGas: String?
    private var nullQuantityFields: Set<WalletConnectEVMQuantityField>

    public init(
        from: String?,
        to: String?,
        data: String,
        value: String,
        nonce: String?,
        gas: String?,
        gasPrice: String?,
        maxFeePerGas: String?,
        maxPriorityFeePerGas: String?
    ) {
        self.from = from
        self.to = to
        self.data = data
        self.value = value
        self.nonce = nonce
        self.gas = gas
        self.gasPrice = gasPrice
        self.maxFeePerGas = maxFeePerGas
        self.maxPriorityFeePerGas = maxPriorityFeePerGas
        self.nullQuantityFields = []
    }
}

public extension WalletConnectEVMTransaction {
    static func == (
        lhs: WalletConnectEVMTransaction,
        rhs: WalletConnectEVMTransaction
    ) -> Bool {
        lhs.from == rhs.from
            && lhs.to == rhs.to
            && lhs.data == rhs.data
            && lhs.value == rhs.value
            && lhs.nonce == rhs.nonce
            && lhs.gas == rhs.gas
            && lhs.gasPrice == rhs.gasPrice
            && lhs.maxFeePerGas == rhs.maxFeePerGas
            && lhs.maxPriorityFeePerGas == rhs.maxPriorityFeePerGas
    }
}

extension WalletConnectEVMTransaction: Decodable {
    enum CodingKeys: String, CodingKey {
        case from
        case to
        case data
        case value
        case nonce
        case gas
        case gasLimit
        case gasPrice
        case maxFeePerGas
        case maxPriorityFeePerGas
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.from = try container.decodeIfPresent(String.self, forKey: .from)
        self.to = try container.decodeIfPresent(String.self, forKey: .to)
        self.data = try container.decodeIfPresent(String.self, forKey: .data) ?? "0x"
        self.value = try container.decodeIfPresent(String.self, forKey: .value) ?? "0x0"
        self.nonce = try container.decodeIfPresent(String.self, forKey: .nonce)
        self.gas = try container.decodeIfPresent(String.self, forKey: .gas)
            ?? container.decodeIfPresent(String.self, forKey: .gasLimit)
        self.gasPrice = try container.decodeIfPresent(String.self, forKey: .gasPrice)
        self.maxFeePerGas = try container.decodeIfPresent(String.self, forKey: .maxFeePerGas)
        self.maxPriorityFeePerGas = try container.decodeIfPresent(String.self, forKey: .maxPriorityFeePerGas)
        self.nullQuantityFields = try Self.nullQuantityFields(in: container)
    }

    private static func nullQuantityFields(
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Set<WalletConnectEVMQuantityField> {
        var fields = Set<WalletConnectEVMQuantityField>()
        if try isNull(.value, in: container) {
            fields.insert(.value)
        }
        if try isNull(.nonce, in: container) {
            fields.insert(.nonce)
        }
        if try isNull(.gas, in: container) || isNull(.gasLimit, in: container) {
            fields.insert(.gas)
        }
        if try isNull(.gasPrice, in: container) {
            fields.insert(.gasPrice)
        }
        if try isNull(.maxFeePerGas, in: container) {
            fields.insert(.maxFeePerGas)
        }
        if try isNull(.maxPriorityFeePerGas, in: container) {
            fields.insert(.maxPriorityFeePerGas)
        }
        return fields
    }

    private static func isNull(
        _ key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Bool {
        guard container.contains(key) else {
            return false
        }
        return try container.decodeNil(forKey: key)
    }
}

enum WalletConnectEVMQuantityField: String, Hashable {
    case value
    case nonce
    case gas
    case gasPrice
    case maxFeePerGas
    case maxPriorityFeePerGas
}

extension WalletConnectEVMTransaction {
    func requiredEVMQuantity(
        _ field: WalletConnectEVMQuantityField
    ) throws(WalletConnectSigningError) -> BigUInt {
        guard !nullQuantityFields.contains(field) else {
            throw Self.invalidEVMQuantity(field: field, value: "null")
        }

        switch field {
        case .value:
            return try Self.parseEVMQuantity(value, field: field)
        case .nonce, .gas, .gasPrice, .maxFeePerGas, .maxPriorityFeePerGas:
            guard let value = optionalQuantityString(for: field) else {
                throw .invalidTransaction(reason: "missing EVM quantity \(field.rawValue)")
            }
            return try Self.parseEVMQuantity(value, field: field)
        }
    }

    func optionalEVMQuantity(
        _ field: WalletConnectEVMQuantityField
    ) throws(WalletConnectSigningError) -> BigUInt? {
        guard !nullQuantityFields.contains(field) else {
            throw Self.invalidEVMQuantity(field: field, value: "null")
        }

        guard let value = optionalQuantityString(for: field) else {
            return nil
        }
        return try Self.parseEVMQuantity(value, field: field)
    }

    private func optionalQuantityString(for field: WalletConnectEVMQuantityField) -> String? {
        switch field {
        case .value:
            return value
        case .nonce:
            return nonce
        case .gas:
            return gas
        case .gasPrice:
            return gasPrice
        case .maxFeePerGas:
            return maxFeePerGas
        case .maxPriorityFeePerGas:
            return maxPriorityFeePerGas
        }
    }

    private static func parseEVMQuantity(
        _ value: String,
        field: WalletConnectEVMQuantityField
    ) throws(WalletConnectSigningError) -> BigUInt {
        let quantity = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prefix = "0x"
        guard quantity.hasPrefix(prefix) else {
            throw invalidEVMQuantity(field: field, value: value)
        }

        let rawHex = String(quantity.dropFirst(prefix.count))
        guard !rawHex.isEmpty else {
            throw invalidEVMQuantity(field: field, value: value)
        }

        let trimmedHex = rawHex.drop { $0 == "0" }
        let hex = trimmedHex.isEmpty ? "0" : String(trimmedHex)
        guard let parsed = BigUInt(hex, radix: 16) else {
            throw invalidEVMQuantity(field: field, value: value)
        }
        return parsed
    }

    private static func invalidEVMQuantity(
        field: WalletConnectEVMQuantityField,
        value: String
    ) -> WalletConnectSigningError {
        .invalidTransaction(reason: "invalid EVM quantity \(field.rawValue): \(value)")
    }
}
