import BigInt
import Foundation
import Testing
import TronSwift
@testable import TronSwiftAPI

struct TronBatchBalancesCallTests {
    @Test
    func payloadContainsTrxAndUsdtCallPerOwner() throws {
        let call = try TronBatchBalancesCall(
            owners: [address(filler: 1), address(filler: 2)],
            usdtContract: address(filler: 9)
        )

        #expect(call.payload.count == 4)
        let methods = call.payload.compactMap { $0["method"] as? String }
        #expect(methods.filter { $0 == "eth_getBalance" }.count == 2)
        #expect(methods.filter { $0 == "eth_call" }.count == 2)
        #expect(call.ownerByTrxRequestId.count == 2)
        #expect(call.ownerByUsdtRequestId.count == 2)
    }

    @Test
    func parseMapsQuantitiesToOwnersById() throws {
        let owner = try address(filler: 1)
        let call = try TronBatchBalancesCall(owners: [owner], usdtContract: address(filler: 9))
        let trxId = try #require(call.ownerByTrxRequestId.first?.key)
        let usdtId = try #require(call.ownerByUsdtRequestId.first?.key)
        let response: [[String: Any]] = [
            ["jsonrpc": "2.0", "id": usdtId, "result": "0x000000000000000000000000000000000000000000000000000000000011169c"],
            ["jsonrpc": "2.0", "id": trxId, "result": "0x0"],
        ]

        let parsed = try call.parse(responseData: JSONSerialization.data(withJSONObject: response))

        #expect(parsed[owner.base58]?.trxAmount == 0)
        #expect(parsed[owner.base58]?.usdtAmount == BigUInt(0x0011_169C))
    }

    @Test
    func parseDropsOwnerWithFailedEntry() throws {
        let healthy = try address(filler: 1)
        let failing = try address(filler: 2)
        let call = try TronBatchBalancesCall(owners: [healthy, failing], usdtContract: address(filler: 9))
        var response = [[String: Any]]()
        for (id, owner) in call.ownerByTrxRequestId {
            if owner == failing.base58 {
                response.append(["jsonrpc": "2.0", "id": id, "error": ["code": -32000, "message": "oops"]])
            } else {
                response.append(["jsonrpc": "2.0", "id": id, "result": "0x5"])
            }
        }
        for (id, _) in call.ownerByUsdtRequestId {
            response.append(["jsonrpc": "2.0", "id": id, "result": "0x7"])
        }

        let parsed = try call.parse(responseData: JSONSerialization.data(withJSONObject: response))

        #expect(parsed[healthy.base58]?.trxAmount == 5)
        #expect(parsed[healthy.base58]?.usdtAmount == 7)
        #expect(parsed[failing.base58] == nil)
    }

    /// A dropped TRX entry must not surface as a zero balance: the amount would be persisted and
    /// then handed back as the "last known" one on the next failure.
    @Test
    func singleOwnerBalancesThrowWhenTrxEntryFailed() throws {
        let owner = try address(filler: 1)
        let call = try TronBatchBalancesCall(owners: [owner], usdtContract: address(filler: 9))
        let trxId = try #require(call.ownerByTrxRequestId.first?.key)
        let usdtId = try #require(call.ownerByUsdtRequestId.first?.key)
        let responseData = try JSONSerialization.data(withJSONObject: [
            ["jsonrpc": "2.0", "id": trxId, "error": ["code": -32000, "message": "oops"]],
            ["jsonrpc": "2.0", "id": usdtId, "result": "0x7"],
        ] as [[String: Any]])

        #expect(throws: JSONRpcResponse.Error.invalidResponse) {
            try call.balances(for: owner, responseData: responseData)
        }
    }

    @Test
    func singleOwnerBalancesMapBothAmounts() throws {
        let owner = try address(filler: 1)
        let call = try TronBatchBalancesCall(owners: [owner], usdtContract: address(filler: 9))
        let trxId = try #require(call.ownerByTrxRequestId.first?.key)
        let usdtId = try #require(call.ownerByUsdtRequestId.first?.key)
        let responseData = try JSONSerialization.data(withJSONObject: [
            ["jsonrpc": "2.0", "id": trxId, "result": "0x5"],
            ["jsonrpc": "2.0", "id": usdtId, "result": "0x7"],
        ] as [[String: Any]])

        let balances = try call.balances(for: owner, responseData: responseData)

        #expect(balances.trxAmount == 5)
        #expect(balances.usdtAmount == 7)
    }

    @Test
    func singleOwnerBalancesThrowWhenUsdtEntryFailed() throws {
        let owner = try address(filler: 1)
        let call = try TronBatchBalancesCall(owners: [owner], usdtContract: address(filler: 9))
        let trxId = try #require(call.ownerByTrxRequestId.first?.key)
        let usdtId = try #require(call.ownerByUsdtRequestId.first?.key)
        let responseData = try JSONSerialization.data(withJSONObject: [
            ["jsonrpc": "2.0", "id": trxId, "result": "0x5"],
            ["jsonrpc": "2.0", "id": usdtId, "error": ["code": -32000, "message": "oops"]],
        ] as [[String: Any]])

        #expect(throws: JSONRpcResponse.Error.invalidResponse) {
            try call.balances(for: owner, responseData: responseData)
        }
    }

    @Test
    func quantityParsesEdgeCases() {
        #expect(TronBatchBalancesCall.quantity(fromHexString: "0x0") == 0)
        #expect(TronBatchBalancesCall.quantity(fromHexString: "0x2a") == 42)
        #expect(TronBatchBalancesCall.quantity(fromHexString: "0x") == nil)
        #expect(TronBatchBalancesCall.quantity(fromHexString: "not-hex") == nil)
    }

    private func address(filler: UInt8) throws -> TronSwift.Address {
        try TronSwift.Address(raw: Data([0x41] + Array(repeating: filler, count: 20)))
    }
}
