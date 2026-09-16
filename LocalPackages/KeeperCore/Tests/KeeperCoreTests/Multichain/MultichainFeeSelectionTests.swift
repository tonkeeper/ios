import BigInt
@testable import KeeperCore
import XCTest

final class MultichainFeeSelectionTests: XCTestCase {
    private let trxFee = BigUInt(4_300_000)
    private let tonFee = BigUInt(150_000_000)
    private let requiredCharges = 10

    // MARK: - Insufficiency

    func test_zeroTRXBalance_marksTRXOptionInsufficient() throws {
        let options = annotated(balances: makeBalances(trx: 0))

        XCTAssertTrue(try option(.trx, in: options).isInsufficient)
    }

    func test_unknownTRXBalance_keepsTRXOptionSufficient() throws {
        let options = annotated(balances: makeBalances(trx: nil))

        XCTAssertFalse(try option(.trx, in: options).isInsufficient)
    }

    func test_tonBalanceBelowFeePlusOwnGas_marksGramOptionInsufficient() throws {
        let justBelow = TronUSDTTonFeePaymentBuilder.requiredTonBalance(for: tonFee) - 1
        let options = annotated(balances: makeBalances(ton: justBelow))

        XCTAssertTrue(try option(.gram, in: options).isInsufficient)
    }

    func test_tonBalanceCoveringFeePlusOwnGas_keepsGramOptionSufficient() throws {
        let exact = TronUSDTTonFeePaymentBuilder.requiredTonBalance(for: tonFee)
        let options = annotated(balances: makeBalances(ton: exact))

        XCTAssertFalse(try option(.gram, in: options).isInsufficient)
    }

    func test_batteryWithoutAuthorization_marksBatteryOptionInsufficient() throws {
        let options = annotated(balances: makeBalances(batteryCharges: .unavailable))

        XCTAssertTrue(try option(.battery, in: options).isInsufficient)
    }

    func test_unknownBatteryBalance_keepsBatteryOptionSufficient() throws {
        let options = annotated(balances: makeBalances(batteryCharges: .unknown))

        XCTAssertFalse(try option(.battery, in: options).isInsufficient)
    }

    func test_batteryChargesBelowRequired_marksBatteryOptionInsufficient() throws {
        let options = annotated(
            balances: makeBalances(batteryCharges: .available(requiredCharges - 1))
        )

        XCTAssertTrue(try option(.battery, in: options).isInsufficient)
    }

    // MARK: - Preselection

    func test_sufficientBattery_doesNotPreselectTRX() {
        let options = annotated(
            balances: makeBalances(batteryCharges: .available(requiredCharges), trx: 0)
        )

        XCTAssertNil(trxTypeToPreselect(in: options))
    }

    /// TK-2638: with Battery unpayable and no TRX, the generic search must be free to land on GRAM.
    func test_insufficientBatteryAndZeroTRX_doesNotPreselectTRX() {
        let options = annotated(
            balances: makeBalances(batteryCharges: .available(0), trx: 0)
        )

        XCTAssertNil(trxTypeToPreselect(in: options))
    }

    func test_insufficientBatteryAndSufficientTRX_preselectsTRX() {
        let options = annotated(
            balances: makeBalances(batteryCharges: .available(0), trx: trxFee)
        )

        XCTAssertEqual(trxTypeToPreselect(in: options)?.isTRXGasless, true)
    }

    func test_manualFeeMethodSelection_disablesTRXPreselection() {
        let options = annotated(
            balances: makeBalances(batteryCharges: .available(0), trx: trxFee)
        )

        XCTAssertNil(
            trxTypeToPreselect(in: options, hasUserSelectedFeeMethod: true)
        )
    }

    func test_nonTronEngine_neverPreselectsTRX() {
        let selection = MultichainFeeSelection(
            engine: .tonJetton(master: "0:jetton-master"),
            transferAmount: 1_000_000
        )
        let options = selection.annotatingInsufficiency(
            makeOptions(),
            balances: makeBalances(batteryCharges: .available(0), trx: trxFee)
        )

        XCTAssertNil(
            selection.trxTypeToPreselect(in: options, hasUserSelectedFeeMethod: false)
        )
    }
}

private extension MultichainFeeSelectionTests {
    enum OptionKind {
        case battery
        case gram
        case trx
    }

    var selection: MultichainFeeSelection {
        MultichainFeeSelection(
            engine: .tronUSDT(tronAddress: "TTronSenderAddress"),
            transferAmount: 1_000_000
        )
    }

    func makeBalances(
        batteryCharges: BatteryChargesAvailability = .available(0),
        ton: BigUInt? = 10_000_000_000,
        trx: BigUInt? = 10_000_000
    ) -> MultichainFeeBalances {
        MultichainFeeBalances(batteryCharges: batteryCharges, ton: ton, trx: trx)
    }

    func makeOptions() -> [TransactionConfirmationModel.ExtraOption] {
        [
            TransactionConfirmationModel.ExtraOption(
                type: .battery,
                value: .battery(charges: requiredCharges, excess: nil)
            ),
            TransactionConfirmationModel.ExtraOption(
                type: .default,
                value: .default(amount: tonFee)
            ),
            TransactionConfirmationModel.ExtraOption(
                type: .gasless(token: TronUSDTFeeOptionsResolver.trxFeeToken),
                value: .gasless(token: TronUSDTFeeOptionsResolver.trxFeeToken, amount: trxFee)
            ),
        ]
    }

    func annotated(balances: MultichainFeeBalances) -> [TransactionConfirmationModel.ExtraOption] {
        selection.annotatingInsufficiency(makeOptions(), balances: balances)
    }

    func trxTypeToPreselect(
        in options: [TransactionConfirmationModel.ExtraOption],
        hasUserSelectedFeeMethod: Bool = false
    ) -> TransactionConfirmationModel.ExtraType? {
        selection.trxTypeToPreselect(
            in: options,
            hasUserSelectedFeeMethod: hasUserSelectedFeeMethod
        )
    }

    func option(
        _ kind: OptionKind,
        in options: [TransactionConfirmationModel.ExtraOption]
    ) throws -> TransactionConfirmationModel.ExtraOption {
        try XCTUnwrap(
            options.first { option in
                switch kind {
                case .battery:
                    return option.type.isBattery
                case .gram:
                    return option.type == .default
                case .trx:
                    return option.type.isTRXGasless
                }
            }
        )
    }
}
