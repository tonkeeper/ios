import Foundation

/// Result of `wallet/gettransactioninfobyid`. An empty JSON object means the node has not
/// indexed the transaction yet.
public struct TronTransactionInfoResponse: Equatable, Sendable {
    public let id: String?
    public let blockNumber: Int64?
    /// `receipt.result` when present. Missing or blank is treated as success.
    public let receiptResult: String?

    public init(id: String?, blockNumber: Int64?, receiptResult: String?) {
        self.id = id
        self.blockNumber = blockNumber
        self.receiptResult = receiptResult
    }

    public var isPresent: Bool {
        id != nil || blockNumber != nil
    }

    public var isSuccessful: Bool {
        guard isPresent else { return false }
        guard let receiptResult, !receiptResult.isEmpty else { return true }
        return receiptResult == "SUCCESS"
    }

    public static func parse(_ json: [String: Any]) -> TronTransactionInfoResponse? {
        let id = json["id"] as? String
        let blockNumber = Self.int64(json["blockNumber"])
        let receipt = json["receipt"] as? [String: Any]
        let receiptResult = (receipt?["result"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let response = TronTransactionInfoResponse(
            id: id,
            blockNumber: blockNumber,
            receiptResult: receiptResult
        )
        return response.isPresent ? response : nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        switch value {
        case let number as Int64:
            return number
        case let number as Int:
            return Int64(number)
        case let number as NSNumber:
            return number.int64Value
        case let string as String:
            return Int64(string)
        default:
            return nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
