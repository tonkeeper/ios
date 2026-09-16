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
}

private extension TransactionConfirmationModelTests {
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
