import Foundation

enum TronRejectionCode {
    static let duplicate = "DUP_TRANSACTION_ERROR"
    static let expiration = "TRANSACTION_EXPIRATION_ERROR"

    static func isExpired(code: String, message: String?) -> Bool {
        if code.uppercased() == expiration {
            return true
        }
        return message?.lowercased().contains("transaction expired") == true
    }

    /// `BANDWITH_ERROR` is how java-tron spells it on the wire; the corrected spelling is kept in
    /// case a node ever fixes the typo.
    private static let insufficientResourceCodes: Set<String> = [
        "BANDWITH_ERROR",
        "BANDWIDTH_ERROR",
        "OUT_OF_ENERGY",
    ]

    private static let insufficientResourceMessages = [
        "account resource insufficient",
        "balance is not sufficient",
        "insufficient balance",
        "not enough energy",
        "not enough bandwidth",
    ]

    static func isInsufficientResources(code: String, message: String?) -> Bool {
        if insufficientResourceCodes.contains(code.uppercased()) {
            return true
        }
        guard let message = message?.lowercased() else {
            return false
        }
        return insufficientResourceMessages.contains { message.contains($0) }
    }

    /// Nodes reuse `PERMISSION_ERROR` and `CONTRACT_VALIDATE_ERROR` for several failures, so only
    /// the message identifies a sender that was never activated.
    static func isAccountMissing(message: String?) -> Bool {
        guard let message else {
            return false
        }
        return message.range(of: "account does not exist", options: .caseInsensitive) != nil
    }
}

/// Reads the failure envelope TRON nodes return from `triggersmartcontract` and
/// `broadcasthex`, where the reason lives in a `code` plus a hex-encoded `message`.
enum TronRejectionResponse {
    static func rejection(in json: [String: Any]) -> TronApi.Error? {
        let payload = (json["result"] as? [String: Any]) ?? json
        let message = decodedMessage(payload["message"])
            ?? decodedMessage(json["message"])
            ?? decodedMessage(json["Error"])

        guard let code = (payload["code"] as? String)?.uppercased(), !code.isEmpty else {
            guard let message else {
                return nil
            }
            return .apiError(message: message)
        }
        return .transactionRejected(code: code, message: message)
    }

    static func decodedMessage(_ raw: Any?) -> String? {
        guard let raw = raw as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return hexDecoded(trimmed) ?? trimmed
    }

    /// Rejects hex that decodes to bytes which are not readable text — a plain message that happens
    /// to be hex ("decade") must survive untouched.
    private static func hexDecoded(_ value: String) -> String? {
        guard value.count.isMultiple(of: 2),
              value.allSatisfy(\.isHexDigit),
              let data = Data(strictHex: value),
              let decoded = String(data: data, encoding: .utf8),
              !decoded.isEmpty,
              decoded.unicodeScalars.allSatisfy({ $0.properties.generalCategory != .control })
        else {
            return nil
        }
        return decoded
    }
}
