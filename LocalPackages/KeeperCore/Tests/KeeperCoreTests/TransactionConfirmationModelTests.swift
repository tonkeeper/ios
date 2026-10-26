@testable import KeeperCore
import TonSwift
import XCTest

final class TransactionConfirmationModelTests: XCTestCase {
    func testSelectedFeeIsInsufficientWhenMatchingOptionIsInsufficient() {
        let model = makeModel(isInsufficient: true)

        XCTAssertTrue(model.isSelectedFeeInsufficient)
    }

    func testSelectedFeeIsSufficientWhenMatchingOptionIsSufficient() {
        let model = makeModel(isInsufficient: false)

        XCTAssertFalse(model.isSelectedFeeInsufficient)
    }

    func testAShortFeeInTheChainsCoinIsANativeFeeShortage() {
        let model = makeMultichainModel(fee: .multichain(token: eth, amount: 42000), isInsufficient: true)

        XCTAssertEqual(model.nativeFeeShortage, MultichainNativeFeeShortage(asset: eth, requiredAmount: 42000))
    }

    /// A relayer's fee in USDT the wallet cannot cover leaves it short of USDT, not of ETH.
    func testAShortFeeInATokenOfTheChainIsNoNativeFeeShortage() {
        let model = makeMultichainModel(fee: .multichain(token: usdt, amount: 500_000), isInsufficient: true)

        XCTAssertTrue(model.isSelectedFeeInsufficient)
        XCTAssertNil(model.nativeFeeShortage)
    }

    func testACoveredFeeInTheChainsCoinIsNoNativeFeeShortage() {
        let model = makeMultichainModel(fee: .multichain(token: eth, amount: 42000), isInsufficient: false)

        XCTAssertNil(model.nativeFeeShortage)
    }
}

private extension TransactionConfirmationModelTests {
    var eth: MultichainAssetDetails {
        MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ether", symbol: "ETH", decimals: 18, image: "")
    }

    var usdt: MultichainAssetDetails {
        MultichainAssetDetails(
            assetId: "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7",
            name: "Tether",
            symbol: "USDT",
            decimals: 6,
            image: ""
        )
    }

    func makeMultichainModel(
        fee: TransactionConfirmationModel.ExtraValue,
        isInsufficient: Bool
    ) -> TransactionConfirmationModel {
        TransactionConfirmationModel(
            wallet: makeWallet(),
            recipient: nil,
            recipientAddress: nil,
            transaction: .transfer(.multichain(
                MultichainAsset(asset: usdt, price: .init(prices: [:], diff24h: [:], diff7d: [:]), balance: 1_000_000)
            )),
            amount: nil,
            extraState: .extra(.init(value: fee, kind: .fee)),
            extraOptions: [
                .init(type: fee.extraType, value: fee, isInsufficient: isInsufficient),
            ],
            availableExtraTypes: [fee.extraType],
            totalFee: 0
        )
    }

    func makeModel(isInsufficient: Bool) -> TransactionConfirmationModel {
        let extraValue = TransactionConfirmationModel.ExtraValue.battery(charges: 1, excess: nil)
        return TransactionConfirmationModel(
            wallet: makeWallet(),
            recipient: nil,
            recipientAddress: nil,
            transaction: .transfer(.ton(false)),
            amount: nil,
            extraState: .extra(.init(value: extraValue, kind: .fee)),
            extraOptions: [
                .init(type: .battery, value: extraValue, isInsufficient: isInsufficient),
            ],
            availableExtraTypes: [.battery],
            totalFee: 0
        )
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Watchonly(
                    .Resolved(
                        try! Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
                    )
                )
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init()
        )
    }
}
