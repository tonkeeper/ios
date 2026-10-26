import Foundation
@testable import KeeperCore
import OpenAPIRuntime
import TKBatteryAPI
import XCTest

/// The generated gasless 2.0 client against responses recorded from production for an Ethereum
/// transfer of 1 USDT: what the relayer is asked, and what is read back from it.
final class BatteryGaslessModelsTests: XCTestCase {
    /// Dates as the battery client reads them: RFC 3339 with or without fractional seconds.
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try MultichainDateTranscoder().decode(decoder.singleValueContainer().decode(String.self))
        }
        return decoder
    }()

    func test_estimateResponse_pricesTheTransferInEveryAsset() throws {
        let response = try decoder.decode(
            Components.Schemas.GaslessV2EstimateResponse.self,
            from: Data(GaslessFixtures.estimate.utf8)
        )

        XCTAssertEqual(response.chain_id, "eth/mainnet")
        XCTAssertEqual(response.sender_address, GaslessFixtures.sender)
        XCTAssertEqual(response.expires_at, date("2026-09-30T10:01:17Z"))
        XCTAssertEqual(
            response.estimations.map(\.asset.id),
            ["battery/mainnet", GaslessFixtures.usdcId, GaslessFixtures.usdtId]
        )
        XCTAssertEqual(response.estimations.map { $0.fee?.data.amount }, ["18", "115304", "115304"])
        XCTAssertEqual(response.estimations.map(\.available), [true, false, true])
        XCTAssertEqual(response.estimations[1].error?.code, "insufficient_funds")
        XCTAssertNil(response.estimations[0].asset.chain)
        XCTAssertEqual(response.estimations[2].asset.decimals, 6)
    }

    func test_emulateResponse_keepsTheOperationAsTheRelayerWroteIt() throws {
        let response = try decoder.decode(
            Components.Schemas.GaslessV2EmulateResponse.self,
            from: Data(GaslessFixtures.emulateBattery.utf8)
        )

        XCTAssertEqual(response.asset_id, "battery/mainnet")
        XCTAssertEqual(response.fee.data.amount, "19")
        XCTAssertEqual(response.expires_at, date("2026-09-30T10:03:11Z"))

        let operation = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(response.operation)
        ) as? [String: Any]
        XCTAssertEqual(operation?["id"] as? String, "bcef74e1-b940-4142-b7a7-76161850971e")
        let payloads = try XCTUnwrap(operation?["payloads"] as? [[String: Any]])
        XCTAssertEqual(payloads.map { $0["type"] as? String }, ["eip7702/authorization", "eip7821/hermes/delegate"])
        // Field names must survive untouched: ChainKit reads the envelope by them.
        XCTAssertEqual(payloads.map { $0["chain_id"] as? String }, ["eth/mainnet", "eth/mainnet"])
        let authorization = try XCTUnwrap(payloads[0]["meta"] as? [String: Any])
        XCTAssertEqual(authorization["nonce"] as? Int, 41)
    }

    func test_estimateRequest_isWrittenAsTheRelayerReadsIt() throws {
        let request = try Components.Schemas.GaslessV2EstimateRequest(
            chain_id: "eth/mainnet",
            sender_address: GaslessFixtures.sender,
            payload: Components.Schemas.GaslessV2Payload(
                id: "p_01",
                _type: "main",
                chain_id: "eth/mainnet",
                version: 1,
                meta: .init(additionalProperties: OpenAPIObjectContainer(unvalidatedValue: [
                    "to": GaslessFixtures.usdtContract, "value": "0", "data": GaslessFixtures.usdtTransfer,
                ]))
            )
        )

        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: Data("""
        {
          "chain_id": "eth/mainnet",
          "sender_address": "\(GaslessFixtures.sender)",
          "payload": {
            "id": "p_01",
            "type": "main",
            "chain_id": "eth/mainnet",
            "version": 1,
            "meta": { "to": "\(GaslessFixtures.usdtContract)", "value": "0", "data": "\(GaslessFixtures.usdtTransfer)" }
          }
        }
        """.utf8)) as? NSDictionary

        XCTAssertEqual(encoded, expected)
    }

    /// `/gasless/send` takes the envelope exactly as ChainKit writes it: a string signature for a
    /// Hermes delegate, a `y_parity`/`r`/`s` object for an EIP-7702 authorization.
    func test_sendRequest_carriesChainKitsEnvelopeUnchanged() throws {
        let envelope = try JSONSerialization.jsonObject(with: Data(GaslessFixtures.signedEnvelope.utf8)) as? NSDictionary

        let request = try JSONDecoder().decode(
            Components.Schemas.GaslessV2SendRequest.self,
            from: Data(GaslessFixtures.signedEnvelope.utf8)
        )
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? NSDictionary

        XCTAssertEqual(request.operation.payloads.map(\._type), ["eip7821/hermes/1/signed", "eip7702/authorization/signed"])
        XCTAssertEqual(encoded, envelope)
    }

    func test_sendResponse_readsTheStatus() throws {
        let response = try decoder.decode(
            Components.Schemas.GaslessV2SendResponse.self,
            from: Data(#"{"operation_id": "bcef74e1-b940-4142-b7a7-76161850971e", "status": "ok"}"#.utf8)
        )

        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.operation_id, "bcef74e1-b940-4142-b7a7-76161850971e")
    }

    func test_rejection_carriesTheRelayersCode() {
        let error = Components.Schemas.GaslessV2ErrorBody(code: "emulation_expired", message: "no such operation, emulate it first")

        guard case let .rejected(status, code, message) = BatteryAPI.gaslessRejection(status: 400, error: error) else {
            return XCTFail("expected a rejection with the relayer's code")
        }
        XCTAssertEqual(status, 400)
        XCTAssertEqual(code, "emulation_expired")
        XCTAssertEqual(message, "no such operation, emulate it first")
        XCTAssertTrue(BatteryEVMGaslessRelayer.expiredErrorCodes.contains(code))
    }

    /// The authorization service recovers the device session from a plain 401, so the gasless
    /// rejection must not hide one behind its own case.
    func test_unauthorized_keepsTheGenericShape() {
        let error = Components.Schemas.GaslessV2ErrorBody(code: "unauthorized", message: "token expired")

        guard case let .badStatus(status, message) = BatteryAPI.gaslessRejection(status: 401, error: error) else {
            return XCTFail("expected a plain bad status")
        }
        XCTAssertEqual(status, 401)
        XCTAssertEqual(message, "token expired")
    }

    func test_config_listsTheChainsServedAndWhatPaysThere() throws {
        let config = try decoder.decode(
            Components.Schemas.GaslessV2Config.self,
            from: Data(GaslessFixtures.config.utf8)
        )

        XCTAssertEqual(
            config.chains.map(\.chain_id),
            ["ton/mainnet", "eth/mainnet", "bsc/mainnet", "arb/mainnet", "base/mainnet", "sol/mainnet"]
        )
        XCTAssertEqual(config.chains.map(\.payload_types), Array(repeating: ["main"], count: 6))
        XCTAssertEqual(config.chains[1].assets.map(\.symbol), ["BATTERY", "USDC", "USDT"])
        XCTAssertNil(config.chains[1].assets[0].chain)
        XCTAssertEqual(config.chains[1].assets[2].id, GaslessFixtures.usdtId)
        XCTAssertEqual(EVMGaslessRelayedChains.relayedEVMChains(in: config), [.eth, .bsc, .arb, .base])
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    func test_unknownFeeTypeDoesNotDiscardOtherEstimations() throws {
        let json = GaslessFixtures.estimate.replacingOccurrences(of: "\"type\": \"value\"", with: "\"type\": \"future-fee\"")
        let response = try decoder.decode(Components.Schemas.GaslessV2EstimateResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.estimations.count, 3)
        XCTAssertEqual(response.estimations[0].fee?._type, .unknown)
    }

    func test_unknownGasSourcesKeepTheEmulation() throws {
        let json = GaslessFixtures.emulateBattery
            .replacingOccurrences(of: "\"estimateGas\"", with: "\"future-source\"")
            .replacingOccurrences(of: "\"gas_price_source\": \"chain\"", with: "\"gas_price_source\": \"future-source\"")
        let response = try decoder.decode(Components.Schemas.GaslessV2EmulateResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.gas?.source, .unknown)
        XCTAssertEqual(response.gas?.gas_price_source, .unknown)
        XCTAssertEqual(response.fee._type, .value)
    }

    func test_unknownPurchaseTypesKeepKnownPurchases() throws {
        let json = #"{"total_purchases":2,"purchases":[{"user_purchase_id":1,"purchase_id":1,"type":"ios","charges":10,"datetime":"2026-10-14T10:00:00Z"},{"user_purchase_id":2,"purchase_id":2,"type":"future-purchase","charges":10,"datetime":"2026-10-14T10:00:00Z"}]}"#
        let response = try decoder.decode(Components.Schemas.Purchases.self, from: Data(json.utf8))
        let purchases = response.purchases.compactMap(BatteryPurchase.init(purchase:))

        XCTAssertEqual(response.purchases[1]._type, .unknown)
        XCTAssertEqual(purchases.map(\.identifier), [1])
        XCTAssertEqual(purchases.first?.kind, .ios)
    }

    func test_unknownRechargeTypesKeepKnownMethods() throws {
        let json = #"{"methods":[{"type":"ton","symbol":"TON","decimals":9,"rate":"1","support_gasless":true,"support_recharge":true},{"type":"future-token","symbol":"NEW","decimals":6,"rate":"1","support_gasless":true,"support_recharge":true}]}"#
        let response = try decoder.decode(Components.Schemas.RechargeMethods.self, from: Data(json.utf8))

        XCTAssertEqual(response.methods[1]._type, .unknown)
        XCTAssertEqual(response.methods.compactMap(BatteryRechargeMethod.init(method:)).map(\.symbol), ["TON"])
    }

    func test_unknownPurchaseErrorUsesExistingUnknownCase() throws {
        typealias Code = Components.Schemas.iOSBatteryPurchaseStatus.transactionsPayloadPayload.errorPayload.codePayload
        let value = try decoder.decode(Code.self, from: Data(#""future-error""#.utf8))

        XCTAssertEqual(value, .unknown)
        XCTAssertEqual(Code.allCases.filter { $0 == .unknown }.count, 1)
    }
}

enum GaslessFixtures {
    static let sender = "0x0eE3CdEE4f010BF6c49aF86E9e67ef2bc80a508b"
    static let usdtContract = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    static let usdtTransfer =
        "0xa9059cbb0000000000000000000000000ee3cdee4f010bf6c49af86e9e67ef2bc80a508b00000000000000000000000000000000000000000000000000000000000f4240"
    static let usdcId = "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
    static let usdtId = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
    static let authorizationMeta =
        #"{ "address": "0x24b576BC271823bF9C24BE627B4363b9b00191e9", "nonce": 41, "chainId": 1 }"#

    static let estimate = """
    {
      "chain_id": "eth/mainnet",
      "sender_address": "\(sender)",
      "created_at": "2026-09-30T09:51:17Z",
      "expires_at": "2026-09-30T10:01:17Z",
      "estimations": [
        {
          "asset": { "id": "battery/mainnet", "name": "Battery", "symbol": "BATTERY", "decimals": 0, "chain": null },
          "available": true,
          "fee": { "type": "value", "asset_id": "battery/mainnet", "data": { "amount": "18" } }
        },
        {
          "asset": { "id": "\(usdcId)", "name": "USDC", "symbol": "USDC", "decimals": 6, "chain": "eth" },
          "available": false,
          "fee": { "type": "value", "asset_id": "\(usdcId)", "data": { "amount": "115304" } },
          "error": { "code": "insufficient_funds", "message": "the account holds none of this token" }
        },
        {
          "asset": { "id": "\(usdtId)", "name": "USDT", "symbol": "USDT", "decimals": 6, "chain": "eth" },
          "available": true,
          "fee": { "type": "value", "asset_id": "\(usdtId)", "data": { "amount": "115304" } }
        }
      ]
    }
    """

    /// `/gasless/battery/config` as recorded from production on 2026-10-07, each chain cut to a few assets.
    static let config = """
    {
      "chains": [
        {
          "chain_id": "ton/mainnet",
          "payload_types": ["main"],
          "assets": [
            { "id": "battery/mainnet", "name": "Battery", "symbol": "BATTERY", "decimals": 0, "image": "https://wallet.tonkeeper.com/img/battery.png", "chain": null },
            { "id": "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe", "name": "USD₮", "symbol": "USD₮", "decimals": 6, "chain": "ton" }
          ]
        },
        {
          "chain_id": "eth/mainnet",
          "payload_types": ["main"],
          "assets": [
            { "id": "battery/mainnet", "name": "Battery", "symbol": "BATTERY", "decimals": 0, "image": "https://wallet.tonkeeper.com/img/battery.png", "chain": null },
            { "id": "\(usdcId)", "name": "USDC", "symbol": "USDC", "decimals": 6, "chain": "eth" },
            { "id": "\(usdtId)", "name": "USDT", "symbol": "USDT", "decimals": 6, "chain": "eth" }
          ]
        },
        {
          "chain_id": "bsc/mainnet",
          "payload_types": ["main"],
          "assets": [
            { "id": "battery/mainnet", "name": "Battery", "symbol": "BATTERY", "decimals": 0, "image": "https://wallet.tonkeeper.com/img/battery.png", "chain": null },
            { "id": "bsc/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955", "name": "USDT", "symbol": "USDT", "decimals": 18, "chain": "bsc" }
          ]
        },
        {
          "chain_id": "arb/mainnet",
          "payload_types": ["main"],
          "assets": [
            { "id": "battery/mainnet", "name": "Battery", "symbol": "BATTERY", "decimals": 0, "image": "https://wallet.tonkeeper.com/img/battery.png", "chain": null },
            { "id": "arb/mainnet/erc20/0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", "name": "USDT", "symbol": "USDT", "decimals": 6, "chain": "arb" }
          ]
        },
        {
          "chain_id": "base/mainnet",
          "payload_types": ["main"],
          "assets": [
            { "id": "battery/mainnet", "name": "Battery", "symbol": "BATTERY", "decimals": 0, "image": "https://wallet.tonkeeper.com/img/battery.png", "chain": null },
            { "id": "base/mainnet/erc20/0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", "name": "USDC", "symbol": "USDC", "decimals": 6, "chain": "base" }
          ]
        },
        {
          "chain_id": "sol/mainnet",
          "payload_types": ["main"],
          "assets": [
            { "id": "battery/mainnet", "name": "Battery", "symbol": "BATTERY", "decimals": 0, "image": "https://wallet.tonkeeper.com/img/battery.png", "chain": null },
            { "id": "sol/mainnet/spl/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v", "name": "USDC", "symbol": "USDC", "decimals": 6, "chain": "sol" }
          ]
        }
      ]
    }
    """

    /// A signed operation as ChainKit's `SignedOperation.toJsonString()` writes it.
    static let signedEnvelope = """
    {
      "operation": {
        "id": "bcef74e1-b940-4142-b7a7-76161850971e",
        "payloads": [
          {
            "type": "eip7821/hermes/1/signed",
            "chain_id": "eth/mainnet",
            "payload_id": "p_02",
            "meta": { "data": "0x5b3c8f1d2a7e9c0b4f6a8d1e3c5b7a9f2d4e6c8b0a1f3e5d7c9b2a4f6e8d0c1b3a5f7e9d1c3b5a7f9e2d4c6b8a0f1e3d5c7b9a2f4e6d8c0b1a3f5e7d9c2b4a6f8e0d1c3b5a7f9e1d3c5b7a9f2d4e6c8b0a1f3e5d7c9b2a4f6e8d0c1b3a5f7e9d1c3b5a7f9e2d4c6b8a0f1e3d5c71b" }
          },
          {
            "type": "eip7702/authorization/signed",
            "chain_id": "eth/mainnet",
            "payload_id": "p_01",
            "meta": { "data": { "y_parity": 1, "r": "0x1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90a", "s": "0x0a9f8e7d6c5b4a392817f6e5d4c3b2a10a9f8e7d6c5b4a392817f6e5d4c3b2a1" } }
          }
        ]
      }
    }
    """

    static let emulateBattery = emulate(assetId: "battery/mainnet", fee: "19")

    static func emulate(assetId: String, fee: String) -> String {
        """
        {
          "chain_id": "eth/mainnet",
          "sender_address": "\(sender)",
          "created_at": "2026-09-30T09:53:11Z",
          "expires_at": "2026-09-30T10:03:11Z",
          "asset_id": "\(assetId)",
          "fee": { "type": "value", "asset_id": "\(assetId)", "data": { "amount": "\(fee)" } },
          "account": {
            "address": "\(sender)",
            "delegated": false,
            "delegated_to": "0x000000005c84F8Fd50b21CAC312528A64437030e",
            "requires_authorization": true,
            "authorization": { "chain_id": 1, "address": "0x24b576BC271823bF9C24BE627B4363b9b00191e9", "nonce": 41 }
          },
          "gas": {
            "estimated": "99141",
            "charged": "102115",
            "authorization_gas": "12500",
            "gas_price_wei": "212233558",
            "source": "estimateGas",
            "gas_price_source": "chain",
            "fee_native_wei": "21672229775170"
          },
          "operation": \(operation(feeAssetId: assetId, fee: fee))
        }
        """
    }

    /// `sender` is the account the Hermes document runs on: the signer refuses any other.
    static func operation(
        feeAssetId: String = "battery/mainnet",
        fee: String = "19",
        sender: String = sender,
        userPayloadType: String = "eip7821/hermes/delegate",
        authorizationPayloadType: String = "eip7702/authorization",
        authorizationMeta: String = authorizationMeta
    ) -> String {
        """
        {
          "id": "bcef74e1-b940-4142-b7a7-76161850971e",
          "type": "transfer",
          "payloads": [
            {
              "id": "p_auth",
              "type": "\(authorizationPayloadType)",
              "chain_id": "eth/mainnet",
              "version": 1,
              "meta": \(authorizationMeta)
            },
            {
              "id": "p_user",
              "type": "\(userPayloadType)",
              "chain_id": "eth/mainnet",
              "version": 1,
              "fee": { "type": "value", "asset_id": "\(feeAssetId)", "data": { "amount": "\(fee)" } },
              "meta": {
                "digest": "0x25de48f18779d904969b06f9b652810bd8dc33055c6f5774c518b4a1acf98748",
                "data": {
                  "domain": {
                    "chainId": 1,
                    "name": "Hermes",
                    "salt": "0x00000000000000000000000024b576bc271823bf9c24be627b4363b9b00191e9",
                    "verifyingContract": "\(sender)",
                    "version": "v1.0.0"
                  },
                  "message": {
                    "calls": [
                      { "data": "\(usdtTransfer)", "target": "\(usdtContract)", "value": "0" }
                    ],
                    "deadline": "1790762591",
                    "mode": "0x0100000000007821000100000000000000000000000000000000000000000000",
                    "nonce": "0"
                  },
                  "primaryType": "Execute",
                  "types": {
                    "Call": [
                      { "name": "target", "type": "address" },
                      { "name": "value", "type": "uint256" },
                      { "name": "data", "type": "bytes" }
                    ],
                    "EIP712Domain": [
                      { "name": "name", "type": "string" },
                      { "name": "version", "type": "string" },
                      { "name": "chainId", "type": "uint256" },
                      { "name": "verifyingContract", "type": "address" },
                      { "name": "salt", "type": "bytes32" }
                    ],
                    "Execute": [
                      { "name": "mode", "type": "bytes32" },
                      { "name": "calls", "type": "Call[]" },
                      { "name": "nonce", "type": "uint256" },
                      { "name": "deadline", "type": "uint256" }
                    ]
                  }
                }
              }
            }
          ]
        }
        """
    }
}
