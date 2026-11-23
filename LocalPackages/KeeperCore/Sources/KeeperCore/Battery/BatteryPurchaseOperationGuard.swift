import BigInt
import Foundation
import TKBatteryAPI
import WalletCore

enum BatteryPurchaseOperationGuard {
    static func check(_ operation: Components.Schemas.GaslessV2Operation, request: BatteryPurchaseRequest) throws {
        for payload in operation.payloads {
            guard payload.chain_id == request.method.chainId else { throw BatteryPurchaseError.invalidQuote }
            if let fee = payload.fee {
                guard fee._type == .value, let amount = fee.data.amount.flatMap({ BigUInt($0) }),
                      amount == 0 || fee.asset_id == "battery/" + (request.method.chainId.split(separator: "/").last.map(String.init) ?? "")
                else { throw BatteryPurchaseError.rejected }
            }
        }
        // TRON has no separate fee-payer key: the relayer grants resources before broadcasting.
        // Its Energy limit includes delegated resources, so a zero limit would also prevent sponsored calls.
        guard request.method.chain == .sol else { return }
        let data = try JSONEncoder().encode(operation)
        guard let document = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payloads = document["payloads"] as? [[String: Any]], !payloads.isEmpty else { throw BatteryPurchaseError.invalidQuote }
        for payload in payloads {
            guard let meta = payload["meta"] as? [String: Any], let transaction = meta["data"] as? String,
                  let payer = solanaFeePayer(transaction), payer != request.sender else { throw BatteryPurchaseError.rejected }
        }
    }

    static func solanaFeePayer(_ transaction: String) -> String? {
        guard let data = Data(base64Encoded: transaction) else { return nil }
        let bytes = Array(data)
        var cursor = 0
        func shortVector() -> Int? {
            var result = 0
            for shift in [0, 7, 14] {
                guard cursor < bytes.count else { return nil }
                let byte = bytes[cursor]
                cursor += 1
                result |= Int(byte & 0x7F) << shift
                if byte & 0x80 == 0 { return result }
            }
            return nil
        }
        guard let signatures = shortVector(), signatures <= 255 else { return nil }
        cursor += signatures * 64
        guard cursor < bytes.count else { return nil }
        if bytes[cursor] & 0x80 != 0 {
            guard bytes[cursor] == 0x80 else { return nil }
            cursor += 1
        }
        cursor += 3
        guard let keys = shortVector(), keys > 0, cursor + keys * 32 <= bytes.count else { return nil }
        return WalletCore.Base58.encodeNoCheck(data: Data(bytes[cursor ..< cursor + 32]))
    }
}
