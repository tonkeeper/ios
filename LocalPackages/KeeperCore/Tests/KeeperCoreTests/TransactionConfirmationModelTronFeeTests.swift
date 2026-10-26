import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class TransactionConfirmationModelTronFeeTests: XCTestCase {
    // MARK: - payableTronFeeType

    func test_batteryShort_movesToTRXBeforeGRAM() {
        let model = makeModel(options: [
            batteryOption(isInsufficient: true),
            gramOption(isInsufficient: false),
            trxOption(isInsufficient: false),
        ])

        XCTAssertTrue(isTRX(model.payableTronFeeType(isInsufficient: \.isInsufficient)))
    }

    func test_batteryAndTRXShort_movesToGRAM() {
        let model = makeModel(options: [
            batteryOption(isInsufficient: true),
            gramOption(isInsufficient: false),
            trxOption(isInsufficient: true),
        ])

        XCTAssertEqual(model.payableTronFeeType(isInsufficient: \.isInsufficient), .default)
    }

    func test_selectedMethodCovers_staysPut() {
        let model = makeModel(options: [
            batteryOption(isInsufficient: false),
            trxOption(isInsufficient: false),
        ])

        XCTAssertNil(model.payableTronFeeType(isInsufficient: \.isInsufficient))
    }

    func test_nothingCovers_hasNowhereToMove() {
        let model = makeModel(options: [
            batteryOption(isInsufficient: true),
            gramOption(isInsufficient: true),
            trxOption(isInsufficient: true),
        ])

        XCTAssertNil(model.payableTronFeeType(isInsufficient: \.isInsufficient))
    }

    func test_feeStillLoading_hasNothingToMove() {
        let model = makeModel(
            options: [batteryOption(isInsufficient: true), trxOption(isInsufficient: false)],
            extraState: .loading
        )

        XCTAssertNil(model.payableTronFeeType(isInsufficient: \.isInsufficient))
    }

    // MARK: - tronFeeShortage

    func test_noMethodCoversTheFee_reportsTheTRXFee() {
        let model = makeModel(options: [
            batteryOption(isInsufficient: true),
            gramOption(isInsufficient: true),
            trxOption(isInsufficient: true),
        ])

        XCTAssertEqual(
            model.tronFeeShortage(isInsufficient: \.isInsufficient),
            TronFeeShortage(requiredTRX: requiredTRX, isBatteryOffered: true)
        )
    }

    func test_anyMethodCoveringTheFee_leavesNothingToReport() {
        let options = [
            batteryOption(isInsufficient: true),
            gramOption(isInsufficient: true),
            trxOption(isInsufficient: true),
        ]
        for covering in options.indices {
            let model = makeModel(options: options.enumerated().map { index, option in
                index == covering ? self.option(option.value, isInsufficient: false) : option
            })

            XCTAssertNil(model.tronFeeShortage(isInsufficient: \.isInsufficient), "option \(covering) covers the fee")
        }
    }

    func test_trxOnlyMethod_reportsTheShortageWithoutBattery() {
        let model = makeModel(options: [trxOption(isInsufficient: true)])

        XCTAssertEqual(
            model.tronFeeShortage(isInsufficient: \.isInsufficient),
            TronFeeShortage(requiredTRX: requiredTRX, isBatteryOffered: false)
        )
    }

    func test_multichainTRC20Transfer_reportsTheShortage() {
        let model = makeModel(
            transaction: .transfer(.multichain(tronUSDT)),
            options: [batteryOption(isInsufficient: true), trxOption(isInsufficient: true)]
        )

        XCTAssertEqual(
            model.tronFeeShortage(isInsufficient: \.isInsufficient),
            TronFeeShortage(requiredTRX: requiredTRX, isBatteryOffered: true)
        )
    }

    func test_trxTransfer_isLeftToTheFundsCheck() {
        let model = makeModel(
            transaction: .transfer(.tronTRX),
            options: [trxOption(isInsufficient: true)]
        )

        XCTAssertNil(model.tronFeeShortage(isInsufficient: \.isInsufficient))
    }

    func test_coinFee_isLeftToTheNativeFeePopup() {
        let fee = TransactionConfirmationModel.ExtraValue.multichain(token: tronUSDT.asset, amount: 1)
        let model = makeModel(
            transaction: .transfer(.multichain(tronUSDT)),
            options: [option(fee, isInsufficient: true)]
        )

        XCTAssertNil(model.tronFeeShortage(isInsufficient: \.isInsufficient))
    }

    func test_feeStillLoading_leavesNothingToReport() {
        let model = makeModel(
            options: [trxOption(isInsufficient: true)],
            extraState: .loading
        )

        XCTAssertNil(model.tronFeeShortage(isInsufficient: \.isInsufficient))
    }

    // MARK: - TronUSDTTransactionConfirmationState.prefer

    func test_preferringAPricedMethod_selectsItsFee() {
        var state = makeState()

        state.prefer(.default)

        XCTAssertEqual(state.selectedExtraType, .default)
        guard case let .extra(extra) = state.extraState, case let .default(amount) = extra.value else {
            return XCTFail("expected the GRAM fee to be selected, got \(state.extraState)")
        }
        XCTAssertEqual(amount, gramFee)
    }

    func test_preferringWhileLoading_keepsTheLoadingState() {
        var state = makeState()
        state.extraState = .loading

        state.prefer(.default)

        XCTAssertEqual(state.preferredExtraType, .default)
        guard case .loading = state.extraState else {
            return XCTFail("expected the fee to stay loading, got \(state.extraState)")
        }
    }
}

private extension TransactionConfirmationModelTronFeeTests {
    var requiredTRX: BigUInt {
        13_046_000
    }

    var gramFee: BigUInt {
        1_200_000_000
    }

    var tronUSDT: MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
                name: "Tether USD",
                symbol: "USD₮",
                decimals: 6,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 10_000_000
        )
    }

    func option(
        _ value: TransactionConfirmationModel.ExtraValue,
        isInsufficient: Bool
    ) -> TransactionConfirmationModel.ExtraOption {
        TransactionConfirmationModel.ExtraOption(
            type: value.extraType,
            value: value,
            isInsufficient: isInsufficient
        )
    }

    func batteryOption(isInsufficient: Bool) -> TransactionConfirmationModel.ExtraOption {
        option(.battery(charges: 45, excess: nil), isInsufficient: isInsufficient)
    }

    func gramOption(isInsufficient: Bool) -> TransactionConfirmationModel.ExtraOption {
        option(.default(amount: gramFee), isInsufficient: isInsufficient)
    }

    func trxOption(isInsufficient: Bool) -> TransactionConfirmationModel.ExtraOption {
        option(
            .gasless(token: TronUSDTFeeOptionsResolver.trxFeeToken, amount: requiredTRX),
            isInsufficient: isInsufficient
        )
    }

    func isTRX(_ type: TransactionConfirmationModel.ExtraType?) -> Bool {
        type?.isTRXGasless ?? false
    }

    func makeState() -> TronUSDTTransactionConfirmationState {
        let options = [
            batteryOption(isInsufficient: false),
            gramOption(isInsufficient: false),
            trxOption(isInsufficient: false),
        ]
        var state = TronUSDTTransactionConfirmationState()
        state.availableTypes = options.map(\.type)
        state.extraOptions = options
        state.preferredExtraType = .battery
        state.extraState = .extra(.init(value: options[0].value, kind: .fee))
        return state
    }

    func makeModel(
        transaction: TransactionConfirmationModel.Transaction = .transfer(.tronUSDT),
        options: [TransactionConfirmationModel.ExtraOption],
        extraState: TransactionConfirmationModel.ExtraState? = nil
    ) -> TransactionConfirmationModel {
        TransactionConfirmationModel(
            wallet: makeWallet(),
            recipient: nil,
            recipientAddress: nil,
            transaction: transaction,
            amount: nil,
            extraState: extraState ?? .extra(.init(value: options[0].value, kind: .fee)),
            extraOptions: options,
            availableExtraTypes: options.map(\.type),
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
