import ChainKit
@testable import KeeperCore
import XCTest

final class SwapFeeResolverTests: XCTestCase {
    func test_batchIsPricedByItsLargestMessage() throws {
        let batch = [
            makeSwap(assetId: "ton/mainnet/coin", amount: 185_000_000, data: "short"),
            makeSwap(assetId: "ton/mainnet/coin", amount: 330_000_000, data: "the longest payload"),
            makeSwap(assetId: "ton/mainnet/coin", amount: 260_000_000, data: "a payload"),
        ]

        let priced = try XCTUnwrap(SwapFeeResolver.pricedMessage(of: batch))

        XCTAssertEqual(priced.amount.description, "330000000")
        XCTAssertEqual(priced.data, "the longest payload")
    }

    func test_jettonMessageIsPricedAsTheCoinMessageItIsOnChain() throws {
        let jettonSwap = makeSwap(assetId: jettonAssetId, amount: 330_000_000, data: "payload")
        let jettonDeposit = makeSwap(assetId: jettonAssetId, amount: 100_000_000, data: nil)
        let coinSwap = makeSwap(assetId: "ton/mainnet/coin", amount: 330_000_000, data: "payload")

        let priced = try XCTUnwrap(SwapFeeResolver.pricedMessage(of: [jettonSwap]))

        XCTAssertTrue(priced.account.asset is AssetCoin)
        XCTAssertEqual(priced.account.address, jettonSwap.account.address)
        XCTAssertEqual(priced.amount.description, "330000000")
        XCTAssertEqual(priced.data, "payload")
        XCTAssertFalse(priced.isMax)
        XCTAssertTrue(SwapFeeResolver.pricedMessage(of: [jettonDeposit])?.account.asset is AssetToken)
        XCTAssertTrue(SwapFeeResolver.pricedMessage(of: [coinSwap]) === coinSwap)
    }

    func test_onlyAJettonMessageWithAPayloadAttachesTheChainCoin() {
        let jettonSwap = makeSwap(assetId: jettonAssetId, amount: 330_000_000, data: "payload")
        let jettonDeposit = makeSwap(assetId: jettonAssetId, amount: 100_000_000, data: nil)
        let coinSwap = makeSwap(assetId: "ton/mainnet/coin", amount: 330_000_000, data: "payload")

        XCTAssertEqual(jettonSwap.attachedEnergy.description, "330000000")
        XCTAssertEqual(jettonDeposit.attachedEnergy.description, "0")
        XCTAssertEqual(coinSwap.attachedEnergy.description, "0")
    }

    func test_batchFee_chargesThePricedMessageForEveryMessage() {
        let fee = FeeValue(asset: tonCoin, amount: BignumBigInteger.Companion.shared.fromInt(int: 12_000_000))

        XCTAssertEqual(SwapFeeResolver.batchFee(fee, messageCount: 3).amount.description, "36000000")
        XCTAssertTrue(SwapFeeResolver.batchFee(fee, messageCount: 1) === fee)
    }

    func test_reservedFee_addsTheAttachedCoinToTheFees() {
        let reserved = SwapFeeResolver().reservedFee(
            [
                FeeValue(asset: tonCoin, amount: BignumBigInteger.Companion.shared.fromInt(int: 10)),
                FeeValue(asset: tonCoin, amount: BignumBigInteger.Companion.shared.fromInt(int: 15)),
            ],
            attachedEnergy: BignumBigInteger.Companion.shared.fromInt(int: 515_000_000),
            asset: tonCoin
        )

        XCTAssertEqual(reserved.amount.description, "515000025")
    }
}

private extension SwapFeeResolverTests {
    var tonCoin: AssetCoin {
        MultichainChain.ton.asChainKitChain.toAsset()
    }

    var jettonAssetId: String {
        "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
    }

    func makeSwap(assetId: String, amount: Int32, data: String?) -> TransactionSwap {
        let chain = MultichainChain.ton.asChainKitChain
        let address = ChainKit.Address.Companion.shared.from(
            value: "UQDjcVuq603VRoJJBLScazVm04HHMWwpd8dmYsHN4JeROjRZ",
            chain: chain,
            type: .default_
        )!
        let coin = chain.toAsset()
        let asset = AssetCompanion.shared.fromString(
            assetId: assetId,
            name: "USDT",
            symbol: "USDT",
            decimals: 6
        )!
        return TransactionSwap(
            account: ChainKit.Account(
                address: address,
                asset: asset,
                derivation: DerivationDefaultPath.shared,
                publicKey: nil
            ),
            amount: BignumBigInteger.Companion.shared.fromInt(int: amount),
            isMax: false,
            destination: ChainKit.Account(
                address: address,
                asset: coin,
                derivation: DerivationDefaultPath.shared,
                publicKey: nil
            ),
            to: address,
            data: data,
            initData: nil,
            memo: nil
        )
    }
}
