import Foundation
@testable import KeeperCore
import MultichainAPI
import OpenAPIRuntime
import TonSwift
import XCTest

final class MultichainActivityMappingTests: XCTestCase {
    func test_everyDomainActivityType_hasMatchingAPISchemaRawValue() {
        for activityType in MultichainActivityType.allCases where activityType != .unknown {
            XCTAssertNotNil(
                MultichainAPI.Components.Schemas.ActivityTypeFilter(rawValue: activityType.rawValue),
                "\(activityType.rawValue) has no matching API schema value"
            )
        }
    }

    func test_activityTypesBeyondTransfersAndSwaps_keepTheirOwnDomainCase() throws {
        let apiActivityTypes: [String] = [
            "stake", "unstake", "mint", "burn", "claim", "withdraw", "contract_call",
        ]

        for apiActivityType in apiActivityTypes {
            let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(activityType: apiActivityType, direction: .out)))

            XCTAssertEqual(activity.activityType.rawValue, apiActivityType)
            XCTAssertNotEqual(activity.activityType, .unknown)
        }
    }

    func test_activityWithUnknownStatusOrDirection_isDropped() throws {
        XCTAssertNil(try MultichainActivity(api: apiActivity(activityType: "send", status: .unknown, direction: .out)))
        XCTAssertNil(try MultichainActivity(api: apiActivity(activityType: "send", direction: .unknown)))
    }

    func test_isSpamFlag_isMappedOrthogonallyToActivityType() throws {
        let spam = try XCTUnwrap(MultichainActivity(api: apiActivity(activityType: "receive", direction: ._in, isSpam: true)))
        XCTAssertTrue(spam.isSpam)
        XCTAssertEqual(spam.activityType, .receive)

        let clean = try XCTUnwrap(MultichainActivity(api: apiActivity(activityType: "receive", direction: ._in, isSpam: nil)))
        XCTAssertFalse(clean.isSpam)
    }

    func test_comment_isReadFromMetaCommentKey() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            meta: ["comment": "555 Telegram Stars \n\nRef#Tnrt9eOdu"]
        )))

        XCTAssertEqual(activity.comment, "555 Telegram Stars \n\nRef#Tnrt9eOdu")
    }

    func test_comment_isNilWhenMetaAbsent() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(activityType: "send", direction: .out)))

        XCTAssertNil(activity.comment)
    }

    func test_comment_isNilWhenMetaHasNoCommentKey() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            meta: ["memo": "unrelated"]
        )))

        XCTAssertNil(activity.comment)
    }

    func test_comment_isNilWhenCommentIsNotAString() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            meta: ["comment": 42]
        )))

        XCTAssertNil(activity.comment)
    }

    func test_aBlankComment_isNone() throws {
        let sender = "0:27bafbc6d4a559505c397864e9e2a68c69ffbea37c61f34b54d114231d3906f3"
        let encrypted: [String: (any Sendable)?] = ["encryption_type": "simple", "cipher_text": "940cff78"]

        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "receive",
            direction: ._in,
            fromAddress: sender,
            meta: ["comment": " \n", "encrypted_comment": encrypted]
        )))

        XCTAssertNil(activity.comment)
        XCTAssertEqual(activity.encryptedComment?.cipherText, "940cff78")
    }

    /// An encrypted comment comes with the address that sent it, which its decryption takes in; one
    /// without a cipher text or a sender is no comment to decrypt.
    func test_encryptedComment_isReadFromMetaWithTheSender() throws {
        let sender = "0:27bafbc6d4a559505c397864e9e2a68c69ffbea37c61f34b54d114231d3906f3"
        let encrypted: [String: (any Sendable)?] = ["encryption_type": "simple", "cipher_text": "940cff78"]

        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "receive",
            direction: ._in,
            fromAddress: sender,
            meta: ["encrypted_comment": encrypted]
        )))
        let noSender = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "receive",
            direction: ._in,
            meta: ["encrypted_comment": encrypted]
        )))
        let noCipherText = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "receive",
            direction: ._in,
            fromAddress: sender,
            meta: ["encrypted_comment": ["encryption_type": "simple", "cipher_text": ""] as [String: (any Sendable)?]]
        )))

        XCTAssertEqual(activity.encryptedComment, MultichainActivityEncryptedComment(cipherText: "940cff78", senderAddress: sender))
        XCTAssertNil(activity.comment)
        XCTAssertEqual(activity.encryptedComment?.payload?.senderAddress.toRaw(), sender)
        XCTAssertEqual(activity.encryptedComment?.payload?.encryptedComment.cipherText, "940cff78")
        XCTAssertNil(noSender.encryptedComment)
        XCTAssertNil(noCipherText.encryptedComment)
    }

    func test_anEncryptedComment_fromANonTonSender_isNone() throws {
        let encrypted: [String: (any Sendable)?] = ["encryption_type": "simple", "cipher_text": "940cff78"]

        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "receive",
            direction: ._in,
            fromAddress: "0x7ECe2D2F3B0C1a8f7c3e5E7bD6A1C4f0d2B95109",
            meta: ["encrypted_comment": encrypted]
        )))

        XCTAssertNil(activity.encryptedComment)
    }

    func test_tronResource_isReadFromMetaTronResourceKey() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            meta: [
                "tron_resource": [
                    "energy": 64285,
                    "bandwidth": 345,
                ] as [String: (any Sendable)?],
            ]
        )))

        XCTAssertEqual(
            activity.tronResource,
            MultichainTronResource(energy: 64285, bandwidth: 345)
        )
    }

    func test_tronResource_isNilWhenBothEnergyAndBandwidthAreZero() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            meta: [
                "tron_resource": [
                    "energy": 0,
                    "bandwidth": 0,
                ] as [String: (any Sendable)?],
            ]
        )))

        XCTAssertNil(activity.tronResource)
    }

    func test_tronResource_isNilWhenMetaHasNoTronResourceKey() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            meta: ["comment": "hi"]
        )))

        XCTAssertNil(activity.tronResource)
    }

    func test_tronResource_acceptsDoubleValuesFromJSONNumbers() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            meta: [
                "tron_resource": [
                    "energy": 100.0,
                    "bandwidth": 20.0,
                ] as [String: (any Sendable)?],
            ]
        )))

        XCTAssertEqual(
            activity.tronResource,
            MultichainTronResource(energy: 100, bandwidth: 20)
        )
    }

    func test_tronResource_isNilWhenDoubleValuesAreNonFinite() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            meta: [
                "tron_resource": [
                    "energy": Double.nan,
                    "bandwidth": Double.infinity,
                ] as [String: (any Sendable)?],
            ]
        )))

        XCTAssertNil(activity.tronResource)
    }

    func test_feeType_isReadFromNestedFeeObject() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            fee: .init(_type: .battery, amount: "3")
        )))

        XCTAssertEqual(activity.feeType, .battery)
        XCTAssertEqual(activity.batteryCharges, 3)
    }

    func test_feeType_fallsBackToFlatFields() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            feeType: .battery,
            feeAmount: "2"
        )))

        XCTAssertEqual(activity.feeType, .battery)
        XCTAssertEqual(activity.batteryCharges, 2)
    }

    func test_feeType_prefersNestedFeeObjectOverFlatFields() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            feeType: .native,
            feeAmount: "1000000",
            fee: .init(_type: .battery, amount: "4")
        )))

        XCTAssertEqual(activity.feeType, .battery)
        XCTAssertEqual(activity.batteryCharges, 4)
    }

    func test_batteryCharges_keepsZeroAsReportedValue() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            fee: .init(_type: .battery, amount: "0")
        )))

        XCTAssertEqual(activity.batteryCharges, 0)
    }

    func test_batteryCharges_acceptsIntegralDecimalString() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            fee: .init(_type: .battery, amount: "5.0")
        )))

        XCTAssertEqual(activity.batteryCharges, 5)
    }

    func test_batteryCharges_isNilWhenAmountMissingOrNotNumeric() throws {
        let missing = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            fee: .init(_type: .battery)
        )))
        XCTAssertEqual(missing.feeType, .battery)
        XCTAssertNil(missing.batteryCharges)

        let garbage = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            fee: .init(_type: .battery, amount: "abc")
        )))
        XCTAssertNil(garbage.batteryCharges)

        let fractional = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            fee: .init(_type: .battery, amount: "1.5")
        )))
        XCTAssertNil(fractional.batteryCharges)
    }

    func test_batteryCharges_isNilForNativeFee() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            feeType: .native,
            feeAmount: "1000000"
        )))

        XCTAssertEqual(activity.feeType, .native)
        XCTAssertNil(activity.batteryCharges)
    }

    func test_feeType_isNilWhenBackendOmitsIt() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "send",
            direction: .out,
            feeAmount: "0"
        )))

        XCTAssertNil(activity.feeType)
        XCTAssertNil(activity.batteryCharges)
    }

    func test_explorerLinks_keepTheTransactionsOfKnownChainsInOrder() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(
            activityType: "swap",
            direction: .out,
            explorerURLs: [
                .init(tx_id: "ton:source", chain: .ton, url: "https://tonviewer.com/transaction/source"),
                .init(tx_id: "new:hash", chain: .unknown, url: "https://example.com/tx/hash"),
                .init(tx_id: "btc:destination", chain: .btc, url: "https://mempool.space/tx/destination"),
            ]
        )))

        XCTAssertEqual(activity.explorerLinks, try [
            MultichainActivityExplorerLink(
                transactionId: "ton:source",
                chain: .ton,
                url: XCTUnwrap(URL(string: "https://tonviewer.com/transaction/source"))
            ),
            MultichainActivityExplorerLink(
                transactionId: "btc:destination",
                chain: .btc,
                url: XCTUnwrap(URL(string: "https://mempool.space/tx/destination"))
            ),
        ])
    }

    func test_explorerLinks_isEmptyWhenBackendOmitsThem() throws {
        let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(activityType: "swap", direction: .out)))

        XCTAssertEqual(activity.explorerLinks, [])
    }

    func test_parties_mapAddressAndName() throws {
        var api = try apiActivity(activityType: "send", direction: .out)
        api.from_address = "0:deprecated"
        api.from = .init(address: "0:from")
        api.to = .init(address: "0:to", name: "alice.ton")

        let activity = try XCTUnwrap(MultichainActivity(api: api))

        XCTAssertEqual(activity.fromAddress, "0:from")
        XCTAssertNil(activity.fromName)
        XCTAssertEqual(activity.toAddress, "0:to")
        XCTAssertEqual(activity.toName, "alice.ton")
    }

    func test_parties_fallBackToFlatAddressesWhenBackendOmitsThem() throws {
        var api = try apiActivity(activityType: "send", direction: .out)
        api.from_address = "0:from"
        api.to_address = "0:to"

        let activity = try XCTUnwrap(MultichainActivity(api: api))

        XCTAssertEqual(activity.fromAddress, "0:from")
        XCTAssertEqual(activity.toAddress, "0:to")
        XCTAssertNil(activity.toName)
    }
}

private extension MultichainActivityMappingTests {
    func apiActivity(
        activityType: String,
        status: MultichainAPI.Components.Schemas.ActivityStatus = .confirmed,
        direction: MultichainAPI.Components.Schemas.ActivityDirection,
        isSpam: Bool? = nil,
        feeType: MultichainAPI.Components.Schemas.ActivityFeeType? = nil,
        feeAmount: String? = nil,
        fee: MultichainAPI.Components.Schemas.ActivityFee? = nil,
        explorerURLs: [MultichainAPI.Components.Schemas.ActivityExplorerLink]? = nil,
        fromAddress: String? = nil,
        meta: [String: (any Sendable)?]? = nil
    ) throws -> MultichainAPI.Components.Schemas.Activity {
        try MultichainAPI.Components.Schemas.Activity(
            activity_type: activityType,
            status: status,
            block_time: Date(timeIntervalSince1970: 0),
            from_chain: "eth",
            to_chain: "eth",
            direction: direction,
            from_address: fromAddress,
            fee_type: feeType,
            fee_amount: feeAmount,
            fee: fee,
            tx_ids: ["eth:hash"],
            explorer_urls: explorerURLs,
            is_spam: isSpam,
            meta: meta.map { try .init(additionalProperties: OpenAPIObjectContainer(unvalidatedValue: $0)) }
        )
    }
}
