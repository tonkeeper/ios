@preconcurrency import BigInt
import Foundation

struct WalletConnectMethodParsingUtilities {
    func paramsData(
        paramsJSON: String,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) -> Data {
        guard let data = paramsJSON.data(using: .utf8) else {
            throw .invalidParams(method: method, reason: "params are not utf8")
        }
        return data
    }

    func data(
        from json: String,
        method: WalletConnectMethod,
        utf8FailureReason: String
    ) throws(WalletConnectRequestParsingError) -> Data {
        guard let data = json.data(using: .utf8) else {
            throw .invalidParams(method: method, reason: utf8FailureReason)
        }
        return data
    }

    func decode<T: Decodable>(
        _ type: T.Type,
        from paramsJSON: String,
        method: WalletConnectMethod,
        failureReason: (Error) -> String
    ) throws(WalletConnectRequestParsingError) -> T {
        let data = try paramsData(paramsJSON: paramsJSON, method: method)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw .invalidParams(method: method, reason: failureReason(error))
        }
    }

    func parseStringList(
        paramsJSON: String,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) -> [String] {
        let data = try paramsData(paramsJSON: paramsJSON, method: method)
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            throw .invalidParams(method: method, reason: "params are not a string array")
        }
    }

    func parseFirst<T: Decodable>(
        _ type: T.Type,
        paramsJSON: String,
        method: WalletConnectMethod
    ) throws(WalletConnectRequestParsingError) -> T {
        let data = try paramsData(paramsJSON: paramsJSON, method: method)
        do {
            guard let first = try JSONDecoder().decode([T].self, from: data).first else {
                throw WalletConnectRequestParsingError.invalidParams(
                    method: method,
                    reason: "params array is empty"
                )
            }
            return first
        } catch let error as WalletConnectRequestParsingError {
            throw error
        } catch {
            throw .invalidParams(method: method, reason: "failed to decode params: \(error.logDescription)")
        }
    }
}

struct WalletConnectUInt256Value: Decodable {
    var value: BigUInt

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedValue: BigUInt

        if let int64 = try? container.decode(Int64.self) {
            guard int64 >= 0 else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "uint256 must not be negative"
                )
            }
            decodedValue = BigUInt(UInt64(int64))
        } else if let uint64 = try? container.decode(UInt64.self) {
            decodedValue = BigUInt(uint64)
        } else {
            let stringValue = try container.decode(String.self)
            guard let value = Self.bigUInt(from: stringValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "failed to create uint256 from \(stringValue)"
                )
            }
            decodedValue = value
        }

        guard decodedValue <= Self.maxValue else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "uint256 is out of range"
            )
        }
        self.value = decodedValue
    }

    private static let maxValue = BigUInt(2).power(256) - 1

    private static func bigUInt(from string: String) -> BigUInt? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("0x") {
            return BigUInt(String(trimmed.dropFirst(2)), radix: 16)
        }
        return BigUInt(trimmed, radix: 10)
    }
}
