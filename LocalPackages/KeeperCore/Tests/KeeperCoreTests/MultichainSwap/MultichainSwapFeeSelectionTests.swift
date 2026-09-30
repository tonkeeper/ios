@testable import KeeperCore
import XCTest

final class MultichainSwapFeeSelectionTests: XCTestCase {
    func testPrefersFirstOptionWhenNothingIsPicked() {
        assertResolves([battery(), native()], picked: nil, to: .battery)
    }

    func testKeepsPickedOption() {
        assertResolves([battery(), native()], picked: .native, to: .native)
    }

    func testFallsBackToNativeWhenPickedOptionIsInsufficient() {
        assertResolves([battery(isInsufficient: true), native()], picked: .battery, to: .native)
    }

    func testDoesNotPreselectInsufficientBattery() {
        assertResolves([battery(isInsufficient: true), native()], picked: nil, to: .native)
    }

    /// A wallet with no native coin left must still land on the relayed method rather than the option
    /// that cannot pay.
    func testPrefersBatteryWhenTheChainCoinCannotPay() {
        assertResolves(
            [battery(), native(isInsufficient: true)],
            picked: nil,
            to: .battery,
            resolvingInsufficient: false
        )
    }

    /// The row still has to exist when nothing can pay, or there is nowhere to reach a refill from.
    func testKeepsInsufficientOptionWhenNothingElseCanPay() {
        assertResolves(
            [battery(isInsufficient: true), native(isInsufficient: true)],
            picked: .battery,
            to: .battery,
            resolvingInsufficient: true
        )
    }

    /// The unpriced row exists to reach a refill, never to be sent: the chain's coin still wins the
    /// selection while it can pay.
    func testUnpricedBatteryIsNotPreselected() {
        assertResolves(
            [MultichainSwapFeeOption(cost: .batteryUnpriced), native()],
            picked: nil,
            to: .native
        )
    }

    /// Battery stays the first offer on a TRON swap, and GRAM is what the picker falls to once the
    /// wallet's own switches take battery away.
    func testGramIsPreselectedWhenItLeadsTheOffer() {
        assertResolves([gram(), native()], picked: nil, to: .gram)
        assertResolves([battery(), gram(), native()], picked: nil, to: .battery)
    }

    func testKeepsPickedGram() {
        assertResolves([battery(), gram(), native()], picked: .gram, to: .gram)
    }

    /// The chain's own coin is still the sanest fallback, even when another relayed method is listed.
    func testFallsBackToNativeWhenGramCannotPay() {
        assertResolves([gram(isInsufficient: true), native()], picked: .gram, to: .native)
    }

    func testResolvesNilWithoutOptions() {
        XCTAssertNil(MultichainSwapFeeSelection.resolve(options: [], picked: .battery))
    }
}

private extension MultichainSwapFeeSelectionTests {
    func assertResolves(
        _ options: [MultichainSwapFeeOption],
        picked: MultichainSwapFeeMethod?,
        to expected: MultichainSwapFeeMethod,
        resolvingInsufficient: Bool? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let resolved = MultichainSwapFeeSelection.resolve(options: options, picked: picked)
        XCTAssertEqual(resolved?.method, expected, file: file, line: line)
        if let resolvingInsufficient {
            XCTAssertEqual(resolved?.isInsufficient, resolvingInsufficient, file: file, line: line)
        }
    }

    func battery(charges: Int = 3, isInsufficient: Bool = false) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(
            cost: .batteryCharges(count: charges, excess: nil, isInsufficient: isInsufficient)
        )
    }

    func gram(isInsufficient: Bool = false) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(
            cost: .gram(amountNano: 12_000_000, isInsufficient: isInsufficient)
        )
    }

    func native(isInsufficient: Bool = false) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(
            cost: .native(
                [
                    MultichainTransactionEmulationResult(
                        fee: 1,
                        asset: MultichainAssetDetails(
                            assetId: "ton/mainnet/coin",
                            name: "Toncoin",
                            symbol: "TON",
                            decimals: 9,
                            image: ""
                        )
                    ),
                ],
                isInsufficient: isInsufficient
            )
        )
    }
}
