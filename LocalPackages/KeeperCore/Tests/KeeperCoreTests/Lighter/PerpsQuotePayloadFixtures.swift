import BigInt
import Foundation
@testable import KeeperCore
import OpenAPIRuntime
import TKPerpsAPI

extension Components.Schemas.QuotePayload {
    static func ton(
        _ id: String,
        chain: String = "ton/mainnet",
        to: String = "EQCrdGsDTqA2t6xRR4N6V4J705F7w_VQbUdHnofsh-8lVIPs",
        value: String,
        body: String? = "te6cckEBAQEASAAAjAAAAAAweGYwNWExZmJj",
        bounce: Bool? = false,
        mode: Int? = 1
    ) -> Self {
        payload(id, chain: chain, meta: Components.Schemas.PayloadMetaTonMain(to: to, value: value, body: body, bounce: bounce, mode: mode))
    }

    static func evm(
        _ id: String,
        chain: String = "eth/mainnet",
        to: String,
        value: String = "0",
        data: String?,
        gas: String? = nil,
        authorization: Components.Schemas.EIP7702AuthorizationTemplate? = nil
    ) -> Self {
        payload(id, chain: chain, meta: Components.Schemas.PayloadMetaEvmMain(to: to, value: value, data: data, gas: gas, authorization: authorization))
    }

    static func tron(_ id: String, to: String, value: String = "0", data: String) -> Self {
        payload(id, chain: "tron/mainnet", meta: Components.Schemas.PayloadMetaEvmMain(to: to, value: value, data: data, gas: nil, authorization: nil))
    }

    static func btc(_ id: String, type: String = "prebuild", psbt: String = BtcFixture.livePsbt) -> Self {
        payload(id, type: type, chain: "btc/mainnet", meta: Components.Schemas.PayloadMetaBtcPrebuild(data: psbt))
    }

    static func payload<Meta: Encodable>(_ id: String, type: String = "main", chain: String, meta: Meta) -> Self {
        // swiftlint:disable:next force_try
        let rawMeta = try! JSONDecoder().decode(OpenAPIObjectContainer.self, from: JSONEncoder().encode(meta))
        // swiftlint:disable:next force_try
        return try! .init(unvalidatedValue: ["id": id, "type": type, "chain_id": chain, "version": 1, "meta": rawMeta.value])
    }

    mutating func setFee(_ fee: Components.Schemas.PayloadFee?) {
        var raw = value
        if let fee {
            // swiftlint:disable:next force_try
            raw["fee"] = try! JSONDecoder().decode(OpenAPIObjectContainer.self, from: JSONEncoder().encode(fee)).value
        } else {
            raw.removeValue(forKey: "fee")
        }
        // swiftlint:disable:next force_try
        self = try! Self(unvalidatedValue: raw)
    }
}

enum BtcFixture {
    /// A live tk-perps relay deposit: 99 707 sats to relay, the change back to `sender`, and the
    /// OP_RETURN relay matches the deposit by.
    static let livePsbt = "cHNidP8BAL4CAAAAAeN/InZ+84d+5IKR6rs1LnheNRl8u0hnj797qsk2CBlHEwAAAAD9////A3uFAQAAAAAAFgAUFtc3gKrpMyWq"
        + "4UpZ+y8B2QnmMg1F7WoAAAAAABYAFNxr+GNUEF3i/NmGiisDdtZzHLkvAAAAAAAAAABEakIweGZiYTQyNDY0MDBjYzEwZGIyZDQ5YjA5"
        + "YmFiZTJmNGNjZGIwNTE2MjRjYmZjMWVlZDMzMTA3NDg2YWExZWYyNjkAAAAAAAEBH013bAAAAAAAFgAU3Gv4Y1QQXeL82YaKKwN21nMc"
        + "uS8AAAAA"
    static let sender = "bc1qm34lsc65zpw79lxes69zkqmk6ee3ewf0j77s3h"
    static let deposited = "99707"

    /// A v0 PSBT of one input and the given outputs, with nothing signed.
    static func psbt(outputs: [(value: UInt64, script: [UInt8])]) -> String {
        var tx: [UInt8] = [2, 0, 0, 0, 1] + [UInt8](repeating: 0, count: 36) + [0, 0xFF, 0xFF, 0xFF, 0xFF]
        tx.append(UInt8(outputs.count))
        for output in outputs {
            tx += withUnsafeBytes(of: output.value.littleEndian, Array.init)
            tx.append(UInt8(output.script.count))
            tx += output.script
        }
        tx += [0, 0, 0, 0]
        let globals: [UInt8] = [1, 0, UInt8(tx.count)] + tx + [0]
        let maps = [UInt8](repeating: 0, count: 1 + outputs.count)
        return Data(Array("psbt".utf8) + [0xFF] + globals + maps).base64EncodedString()
    }
}

/// Tron addresses whose 20 bytes the calldata fixtures spell.
enum TronFixture {
    static let sender = "TD5gsCwxykWsLN9aPrq2TAfNjByuZKYp4E"
    static let usdt = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
    /// `0xf0623e1012177482912fb057e44e1a9769b1f588` behind Tron's `0x41`.
    static let router = "TXtEs6t2oUWQsNos7m68gbHdE9Q5n6x2oN"
    static let routerHex = "f0623e1012177482912fb057e44e1a9769b1f588"

    /// As Tron spells calldata: no `0x`.
    static func approve(spenderHex: String = routerHex, amountUnits: String) -> String {
        String(HermesBatchFixture.approve(spender: "0x" + spenderHex, amountUnits: amountUnits).dropFirst(2))
    }
}

/// ERC-7821 `execute` calldata, encoded here independently of the reader it is checked by.
enum HermesBatchFixture {
    static func execute(_ calls: [(to: String, data: String)], mode: String = PerpsDepositCalldata.plainBatchMode) -> String {
        func word(_ value: Int) -> String {
            let hex = String(value, radix: 16)
            return String(repeating: "0", count: 64 - hex.count) + hex
        }
        let tails = calls.map { call -> String in
            let data = String(call.data.dropFirst(2))
            let padding = String(repeating: "0", count: (64 - data.count % 64) % 64)
            return String(repeating: "0", count: 24) + call.to.dropFirst(2) + word(0) + word(0x60) + word(data.count / 2) + data + padding
        }
        var offsets = ""
        var offset = calls.count * 32
        for tail in tails {
            offsets += word(offset)
            offset += tail.count / 2
        }
        let executionData = word(0x20) + word(calls.count) + offsets + tails.joined()
        return "0x" + PerpsDepositCalldata.executeSelector + mode + word(0x40) + word(executionData.count / 2) + executionData
    }

    static func approve(spender: String, amountUnits: String) -> String {
        let hex = String(BigUInt(amountUnits) ?? 0, radix: 16)
        return "0x" + PerpsDepositCalldata.approveSelector
            + String(repeating: "0", count: 24) + spender.dropFirst(2)
            + String(repeating: "0", count: 64 - hex.count) + hex
    }

    static func authorization(nonce: Int64 = 12, address: String = PerpsDepositCalldata.hermesDelegate) -> Components.Schemas.EIP7702AuthorizationTemplate {
        .init(chainId: 1, address: address, nonce: nonce)
    }
}

extension Components.Schemas.DepositOperation {
    /// The payloads go in as the backend sends them: raw JSON, which ChainKit reads.
    static func transfer(id: String = "op-1", _ payloads: [Components.Schemas.QuotePayload]) -> Self {
        .init(id: id, payloads: payloads)
    }
}
