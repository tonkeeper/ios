@testable import App
import BigInt
@testable import KeeperCore
import XCTest

final class BatteryRechargeChargesCountTests: XCTestCase {
    private struct StubUnit: AmountInputUnit {
        let inputSymbol: AmountInputSymbol
        let fractionalDigits: Int
        let symbol: String
    }

    private let tonUnit = StubUnit(inputSymbol: .text("TON"), fractionalDigits: 9, symbol: "TON")
    private let usdtUnit = StubUnit(inputSymbol: .text("USDT"), fractionalDigits: 6, symbol: "USDT")
    private let tonChargeRate = BatteryRechargeChargesCountTests.makeTonChargeRate(meanFees: "0.0026", methodRate: "0.9")
    private let usdtChargeRate = BatteryRechargeChargesCountTests.makeTonChargeRate(
        meanFees: "0.0026",
        methodRate: "0.67294751009421267"
    )

    func test_amountBelowOneChargeGivesNoCharges() {
        XCTAssertEqual(chargesCount("0.002", unit: tonUnit, rate: tonChargeRate), 0)
        XCTAssertEqual(chargesCount("0.0028", unit: tonUnit, rate: tonChargeRate), 0)
        XCTAssertEqual(chargesCount("0.000009", unit: usdtUnit, rate: usdtChargeRate), 0)
        XCTAssertEqual(chargesCount("0.003", unit: usdtUnit, rate: usdtChargeRate), 0)
        XCTAssertEqual(chargesCount("0.0038", unit: usdtUnit, rate: usdtChargeRate), 0)
    }

    func test_amountCountsOnlyWholeCharges() {
        XCTAssertEqual(chargesCount("0.0029", unit: tonUnit, rate: tonChargeRate), 1)
        XCTAssertEqual(chargesCount("0.003", unit: tonUnit, rate: tonChargeRate), 1)
        XCTAssertEqual(chargesCount("1", unit: tonUnit, rate: tonChargeRate), 346)
        XCTAssertEqual(chargesCount("0.0039", unit: usdtUnit, rate: usdtChargeRate), 1)
        XCTAssertEqual(chargesCount("0.004", unit: usdtUnit, rate: usdtChargeRate), 1)
    }

    func test_zeroAmountGivesNoCharges() {
        XCTAssertEqual(
            BatteryRechargeModel.chargesCount(amount: 0, fractionDigits: 9, tonChargeRate: tonChargeRate),
            0
        )
    }

    func test_chargesCountMatchesConvertedAmountUnderInput() {
        let cases: [(String, StubUnit, NSDecimalNumber)] = [
            ("0.001", tonUnit, tonChargeRate),
            ("0.002", tonUnit, tonChargeRate),
            ("0.0028", tonUnit, tonChargeRate),
            ("0.0029", tonUnit, tonChargeRate),
            ("1", tonUnit, tonChargeRate),
            ("0.000009", usdtUnit, usdtChargeRate),
            ("0.002", usdtUnit, usdtChargeRate),
            ("0.0038", usdtUnit, usdtChargeRate),
            ("0.0039", usdtUnit, usdtChargeRate),
        ]

        for (input, unit, rate) in cases {
            let amountInput = makeAmountInput(sourceUnit: unit)
            amountInput.rate = rate
            amountInput.setText(input)

            XCTAssertEqual(
                amountInput.converted.text,
                String(chargesCount(input, unit: unit, rate: rate)),
                "\(input) \(unit.symbol)"
            )
        }
    }

    func test_typedChargesConvertToAmountBuyingTheSameCharges() {
        let charges = [1, 2, 3, 7, 25, 100, 346, 750, 1250, 2000]

        for (unit, rate) in [(tonUnit, tonChargeRate), (usdtUnit, usdtChargeRate)] {
            for count in charges {
                let amountInput = makeAmountInput(sourceUnit: unit)
                amountInput.rate = rate
                var sourceAmount = BigUInt(0)
                amountInput.didUpdateSourceAmount = { sourceAmount = $0 }
                amountInput.toggle()
                amountInput.setText(String(count))

                XCTAssertEqual(
                    BatteryRechargeModel.chargesCount(
                        amount: sourceAmount,
                        fractionDigits: unit.fractionalDigits,
                        tonChargeRate: rate
                    ),
                    BigUInt(count),
                    "\(count) charges in \(unit.symbol)"
                )
            }
        }
    }

    private func chargesCount(_ input: String, unit: StubUnit, rate: NSDecimalNumber) -> BigUInt {
        let amount = AmountInputFormatter.amount(from: input, targetFractionalDigits: unit.fractionalDigits).amount
        return BatteryRechargeModel.chargesCount(
            amount: amount,
            fractionDigits: unit.fractionalDigits,
            tonChargeRate: rate
        )
    }

    private func makeAmountInput(sourceUnit: StubUnit) -> AmountInputSwiftUIViewModel {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountInputSwiftUIViewModel(
            amountFormatter: AmountFormatter(configuration: configuration),
            sourceUnit: sourceUnit,
            destinationUnit: ChargeItem()
        )
    }

    private static func makeTonChargeRate(meanFees: String, methodRate: String) -> NSDecimalNumber {
        let behavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 20,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let chargeTonRate = NSDecimalNumber(string: meanFees)
            .dividing(by: NSDecimalNumber(string: methodRate), withBehavior: behavior)
        return NSDecimalNumber(value: 1).dividing(by: chargeTonRate, withBehavior: behavior)
    }
}
