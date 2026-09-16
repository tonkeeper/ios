import BigInt
@testable import KeeperCore
import XCTest

final class SwapConfirmationGasRequirementTests: XCTestCase {
    func test_requiredGasAmount_usesGasBudgetRatherThanEstimatedConsumption() {
        let confirmation = makeConfirmation(gasBudget: "40500000", estimatedGasConsumption: "40000000")

        XCTAssertEqual(confirmation.requiredGasAmount, 40_500_000)
    }

    func test_requiredGasAmount_doesNotAddEstimatedConsumptionToGasBudget() {
        let confirmation = makeConfirmation(gasBudget: "40500000", estimatedGasConsumption: "40000000")

        XCTAssertNotEqual(confirmation.requiredGasAmount, 80_500_000)
    }

    func test_requiredGasAmount_fallsBackToEstimatedConsumptionWhenGasBudgetIsEmpty() {
        let confirmation = makeConfirmation(gasBudget: "", estimatedGasConsumption: "40000000")

        XCTAssertEqual(confirmation.requiredGasAmount, 40_000_000)
    }

    func test_requiredGasAmount_fallsBackToEstimatedConsumptionWhenGasBudgetIsNotANumber() {
        let confirmation = makeConfirmation(gasBudget: "n/a", estimatedGasConsumption: "40000000")

        XCTAssertEqual(confirmation.requiredGasAmount, 40_000_000)
    }

    func test_requiredGasAmount_isZeroWhenBothValuesAreNotNumbers() {
        let confirmation = makeConfirmation(gasBudget: "n/a", estimatedGasConsumption: "n/a")

        XCTAssertEqual(confirmation.requiredGasAmount, 0)
    }

    private func makeConfirmation(
        gasBudget: String,
        estimatedGasConsumption: String
    ) -> SwapConfirmation {
        SwapConfirmation(
            messages: [],
            quoteId: "quote",
            resolverName: "resolver",
            askUnits: "1000",
            bidUnits: "1000",
            protocolFeeUnits: "0",
            tradeStartDeadline: "0",
            gasBudget: gasBudget,
            estimatedGasConsumption: estimatedGasConsumption,
            slippage: 100,
            valueDifferenceBps: nil
        )
    }
}
