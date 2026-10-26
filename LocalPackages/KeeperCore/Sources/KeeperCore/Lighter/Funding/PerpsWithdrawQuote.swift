import BigInt
import Foundation
import TKPerpsAPI

@frozen public enum PerpsWithdrawQuoteError: Error, Equatable {
    case expired
    case mismatch(String)
    case malformed(String)
    case unsafeTransfer
    case overspend
}

struct PerpsWithdrawQuote: Sendable, Equatable {
    let quoteId: String
    let expiresAt: Date
    let executionId: String
    let destinationAssetId: String
    let recipient: String
    let budgetUnits: String
    let outputUnits: String
    let minimumOutputUnits: String
    let toAccountIndex: Int64
    let transferUnits: Int64
    let feeUnits: Int64
    let memo: Data
}

enum PerpsWithdrawQuoteReader {
    static func read(
        _ quote: Components.Schemas.WithdrawQuote,
        request: Components.Schemas.WithdrawQuoteRequest,
        accountIndex: Int64,
        now: Date
    ) throws -> PerpsWithdrawQuote {
        guard quote.expires_at > now else { throw PerpsWithdrawQuoteError.expired }
        guard quote.input.asset_id.lowercased() == PerpsFundingAssetId.usdcEthereum,
              quote.input.amount == request.amount,
              quote.input.account_index == accountIndex
        else { throw PerpsWithdrawQuoteError.mismatch("input") }
        guard quote.output.asset_id.lowercased() == request.destination_asset.lowercased(),
              PerpsFundingAssetId.sameAddress(quote.output.address, request.recipient_address)
        else { throw PerpsWithdrawQuoteError.mismatch("destination") }
        guard let executionId = quote.tracking?.execution_id, !executionId.isEmpty else {
            throw PerpsWithdrawQuoteError.malformed("tracking")
        }
        let budget = try units(request.amount, "budget")
        let output = try units(quote.output.amount, "output")
        let minimum = try units(quote.output.min_amount, "minimum")
        guard budget > 0, output > 0, minimum > 0, minimum <= output else {
            throw PerpsWithdrawQuoteError.malformed("amount")
        }
        guard quote.operation.payloads.count == 1,
              let raw = quote.operation.payloads.first,
              let payload = try? JSONDecoder().decode(LighterTransferPayload.self, from: JSONEncoder().encode(raw)),
              payload.type == "main", payload.version == 1,
              payload.chainId.lowercased() == "lighter/mainnet"
        else { throw PerpsWithdrawQuoteError.unsafeTransfer }
        let meta = payload.meta
        guard meta.asset_index == 3,
              meta.from_route_type == 0,
              meta.to_route_type == 0,
              meta.to_account_index > 0,
              meta.to_account_index != accountIndex
        else { throw PerpsWithdrawQuoteError.unsafeTransfer }
        let amount = try units(meta.amount, "transfer amount")
        let fee = try units(meta.usdc_fee, "transfer fee")
        guard amount > 0, amount + fee <= budget,
              let amountInt = try? PerpsFundingAmount.int64Units(amount),
              let feeInt = try? PerpsFundingAmount.int64Units(fee)
        else { throw PerpsWithdrawQuoteError.overspend }
        guard meta.memo.hasPrefix("0x") else { throw PerpsWithdrawQuoteError.unsafeTransfer }
        let hex = String(meta.memo.dropFirst(2))
        let bytes = (0 ..< 32).compactMap { index in
            UInt8(hex.dropFirst(index * 2).prefix(2), radix: 16)
        }
        guard hex.count == 64, bytes.count == 32 else { throw PerpsWithdrawQuoteError.unsafeTransfer }
        let memo = Data(bytes)
        return PerpsWithdrawQuote(
            quoteId: quote.quote_id,
            expiresAt: quote.expires_at,
            executionId: executionId,
            destinationAssetId: request.destination_asset,
            recipient: request.recipient_address,
            budgetUnits: budget.description,
            outputUnits: output.description,
            minimumOutputUnits: minimum.description,
            toAccountIndex: meta.to_account_index,
            transferUnits: amountInt,
            feeUnits: feeInt,
            memo: memo
        )
    }

    /// The generated meta union takes the first case that parses, so a field the meta gains
    /// can hand it to another chain's case; the type and chain say which meta this is.
    private struct LighterTransferPayload: Decodable {
        let type: String
        let chainId: String
        let version: Int
        let meta: Components.Schemas.PayloadMetaLighterTransfer

        private enum CodingKeys: String, CodingKey {
            case type
            case chainId = "chain_id"
            case version
            case meta
        }
    }

    private static func units(_ value: String, _ field: String) throws -> BigUInt {
        do { return try PerpsFundingAmount.integerUnits(value) }
        catch { throw PerpsWithdrawQuoteError.malformed(field) }
    }
}
