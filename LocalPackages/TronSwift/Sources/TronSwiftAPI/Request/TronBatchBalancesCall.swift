import BigInt
import Foundation
import TronSwift

public struct TronBatchAccountBalances {
    public let trxAmount: BigUInt
    public let usdtAmount: BigUInt

    public init(trxAmount: BigUInt, usdtAmount: BigUInt) {
        self.trxAmount = trxAmount
        self.usdtAmount = usdtAmount
    }
}

/// One JSON-RPC 2.0 batch with eth_getBalance + eth_call(balanceOf) per owner:
/// TronGrid counts the whole batch as a single request, so N addresses cost one
/// slot of the per-method budget instead of 2N.
struct TronBatchBalancesCall {
    let payload: [[String: Any]]
    let ownerByTrxRequestId: [String: String]
    let ownerByUsdtRequestId: [String: String]

    init(owners: [Address], usdtContract: Address) {
        var payload = [[String: Any]]()
        var ownerByTrxRequestId = [String: String]()
        var ownerByUsdtRequestId = [String: String]()

        for owner in owners {
            let trxRequest = JSONRpcRequest(
                method: "eth_getBalance",
                params: [owner.notPrefixed().hexString(), "latest"]
            )
            ownerByTrxRequestId[trxRequest.id] = owner.base58
            payload.append(trxRequest.parameters())

            let usdtRequest = ContractCallRequest.request(
                contractAddress: usdtContract,
                data: BalanceOfMethod(owner: owner).encode()
            )
            ownerByUsdtRequestId[usdtRequest.id] = owner.base58
            payload.append(usdtRequest.parameters())
        }

        self.payload = payload
        self.ownerByTrxRequestId = ownerByTrxRequestId
        self.ownerByUsdtRequestId = ownerByUsdtRequestId
    }

    /// Owners with a failed or unparsable entry are dropped, not zeroed: the
    /// caller falls back to per-address loading for anything missing.
    func parse(responseData: Data) throws -> [String: TronBatchAccountBalances] {
        guard let items = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] else {
            throw JSONRpcResponse.Error.invalidResponse
        }

        var trxByOwner = [String: BigUInt]()
        var usdtByOwner = [String: BigUInt]()

        for json in items {
            guard let item = try? JSONRpcResponse.SuccessResponse(json: json),
                  let hexString = item.result as? String,
                  let amount = Self.quantity(fromHexString: hexString)
            else {
                continue
            }
            if let owner = ownerByTrxRequestId[item.id] {
                trxByOwner[owner] = amount
            } else if let owner = ownerByUsdtRequestId[item.id] {
                usdtByOwner[owner] = amount
            }
        }

        return ownerByTrxRequestId.values.reduce(into: [String: TronBatchAccountBalances]()) { result, owner in
            guard let trxAmount = trxByOwner[owner], let usdtAmount = usdtByOwner[owner] else { return }
            result[owner] = TronBatchAccountBalances(trxAmount: trxAmount, usdtAmount: usdtAmount)
        }
    }

    /// An unanswered entry is not a zero balance, so the pair is dropped here too: the caller
    /// keeps its last known amounts rather than persisting a fabricated one.
    func balances(for owner: Address, responseData: Data) throws -> TronAccountBalances {
        guard let balances = try parse(responseData: responseData)[owner.base58] else {
            throw JSONRpcResponse.Error.invalidResponse
        }
        return TronAccountBalances(
            trxAmount: balances.trxAmount,
            usdtAmount: balances.usdtAmount
        )
    }

    static func quantity(fromHexString hexString: String) -> BigUInt? {
        var hex = hexString.lowercased()
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }
        guard !hex.isEmpty else {
            return nil
        }
        return BigUInt(hex, radix: 16)
    }
}
