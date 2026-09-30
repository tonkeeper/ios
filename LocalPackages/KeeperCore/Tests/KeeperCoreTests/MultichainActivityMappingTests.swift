import Foundation
@testable import KeeperCore
import MultichainAPI
import OpenAPIRuntime
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
        let apiActivityTypes: [MultichainAPI.Components.Schemas.ActivityType] = [
            "stake", "unstake", "mint", "burn", "claim", "withdraw", "contract_call",
        ]

        for apiActivityType in apiActivityTypes {
            let activity = try XCTUnwrap(MultichainActivity(api: apiActivity(activityType: apiActivityType, direction: .out)))

            XCTAssertEqual(activity.activityType.rawValue, apiActivityType)
            XCTAssertNotEqual(activity.activityType, .unknown)
        }
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
}

private extension MultichainActivityMappingTests {
    func apiActivity(
        activityType: MultichainAPI.Components.Schemas.ActivityType,
        direction: MultichainAPI.Components.Schemas.ActivityDirection,
        isSpam: Bool? = nil,
        feeType: MultichainAPI.Components.Schemas.ActivityFeeType? = nil,
        feeAmount: String? = nil,
        fee: MultichainAPI.Components.Schemas.ActivityFee? = nil,
        meta: [String: (any Sendable)?]? = nil
    ) throws -> MultichainAPI.Components.Schemas.Activity {
        try MultichainAPI.Components.Schemas.Activity(
            activity_type: activityType,
            status: .confirmed,
            block_time: Date(timeIntervalSince1970: 0),
            from_chain: "eth",
            to_chain: "eth",
            direction: direction,
            fee_type: feeType,
            fee_amount: feeAmount,
            fee: fee,
            tx_ids: ["eth:hash"],
            is_spam: isSpam,
            meta: meta.map { try .init(additionalProperties: OpenAPIObjectContainer(unvalidatedValue: $0)) }
        )
    }
}
