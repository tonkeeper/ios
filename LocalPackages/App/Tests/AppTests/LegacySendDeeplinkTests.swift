@testable import App
import BigInt
@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class LegacySendDeeplinkAssetTests: XCTestCase {
    private let jettonAddress = "EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"

    func test_tonCoin_mapsToTon() {
        let asset = LegacySendDeeplinkAsset(assetId: "ton/mainnet/coin")

        XCTAssertEqual(asset, .ton)
        XCTAssertEqual(asset?.chain, .ton)
        XCTAssertNil(asset?.jettonAddress)
    }

    func test_tonJetton_mapsToJettonAddress() throws {
        let asset = LegacySendDeeplinkAsset(assetId: "ton/mainnet/jetton/\(jettonAddress)")

        XCTAssertEqual(asset, try .jetton(TonSwift.Address.parse(jettonAddress)))
        XCTAssertEqual(asset?.chain, .ton)
        XCTAssertEqual(asset?.jettonAddress, try TonSwift.Address.parse(jettonAddress))
    }

    func test_tronUSDT_mapsToTronUSDT() {
        let asset = LegacySendDeeplinkAsset(
            assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)"
        )

        XCTAssertEqual(asset, .tronUSDT)
        XCTAssertEqual(asset?.chain, .tron)
        XCTAssertNil(asset?.jettonAddress)
    }

    func test_tronNonUSDTToken_isRejected() {
        XCTAssertNil(
            LegacySendDeeplinkAsset(assetId: "tron/mainnet/trc20/TU4vEruvZwLLkSfV9bNw12EJTPvNr7Pvaa")
        )
    }

    func test_evmAsset_isRejected() {
        XCTAssertNil(LegacySendDeeplinkAsset(assetId: "eth/mainnet/coin"))
        XCTAssertNil(
            LegacySendDeeplinkAsset(
                assetId: "base/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
            )
        )
    }

    func test_unknownTonStandard_isRejected() {
        XCTAssertNil(LegacySendDeeplinkAsset(assetId: "ton/mainnet/nft/\(jettonAddress)"))
    }

    func test_jettonWithMalformedAddress_isRejected() {
        XCTAssertNil(LegacySendDeeplinkAsset(assetId: "ton/mainnet/jetton/not-an-address"))
    }

    func test_malformedAssetId_isRejected() {
        XCTAssertNil(LegacySendDeeplinkAsset(assetId: "ton/mainnet"))
        XCTAssertNil(LegacySendDeeplinkAsset(assetId: "ton"))
        XCTAssertNil(LegacySendDeeplinkAsset(assetId: "unknownchain/mainnet/coin"))
    }
}

final class LegacySendDeeplinkPlanTests: XCTestCase {
    private let jetton = try! TonSwift.Address.parse("EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs")
    private let otherJetton = try! TonSwift.Address.parse(
        "0:2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc"
    )

    func test_withoutAssetId_keepsJettonAndAmount() {
        let plan = LegacySendDeeplinkPlan(
            assetId: nil,
            jettonAddress: jetton,
            amount: 1000,
            recipientChain: .ton
        )

        XCTAssertEqual(plan.jettonAddress, jetton)
        XCTAssertEqual(plan.amount, 1000)
    }

    func test_assetIdNamingTonCoin_dropsJetton() {
        let plan = LegacySendDeeplinkPlan(
            assetId: "ton/mainnet/coin",
            jettonAddress: jetton,
            amount: 1000,
            recipientChain: .ton
        )

        XCTAssertNil(plan.jettonAddress)
        XCTAssertEqual(plan.amount, 1000)
    }

    func test_assetIdNamingJetton_winsOverJettonParameter() {
        let plan = LegacySendDeeplinkPlan(
            assetId: "ton/mainnet/jetton/\(otherJetton.toRaw())",
            jettonAddress: jetton,
            amount: 1000,
            recipientChain: .ton
        )

        XCTAssertEqual(plan.jettonAddress, otherJetton)
        XCTAssertEqual(plan.amount, 1000)
    }

    func test_assetIdNamingTronUSDT_onTronRecipient_isHonoured() {
        let plan = LegacySendDeeplinkPlan(
            assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)",
            jettonAddress: nil,
            amount: 1000,
            recipientChain: .tron
        )

        XCTAssertNil(plan.jettonAddress)
        XCTAssertEqual(plan.amount, 1000)
    }

    /// The link is meant to serve a multichain wallet too, so an out-of-reach asset falls back to
    /// `jetton` — without the amount, which was denominated in the asset that got dropped.
    func test_unreachableAssetId_fallsBackToJettonWithoutAmount() {
        let plan = LegacySendDeeplinkPlan(
            assetId: "base/mainnet/erc20/0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
            jettonAddress: jetton,
            amount: 1000,
            recipientChain: .ton
        )

        XCTAssertEqual(plan.jettonAddress, jetton)
        XCTAssertNil(plan.amount)
    }

    func test_assetIdFromAnotherChainThanRecipient_isDropped() {
        let plan = LegacySendDeeplinkPlan(
            assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)",
            jettonAddress: jetton,
            amount: 1000,
            recipientChain: .ton
        )

        XCTAssertEqual(plan.jettonAddress, jetton)
        XCTAssertNil(plan.amount)
    }

    func test_malformedAssetId_fallsBackToTonWithoutAmount() {
        let plan = LegacySendDeeplinkPlan(
            assetId: "definitely-not-an-asset",
            jettonAddress: nil,
            amount: 1000,
            recipientChain: .ton
        )

        XCTAssertNil(plan.jettonAddress)
        XCTAssertNil(plan.amount)
    }
}
