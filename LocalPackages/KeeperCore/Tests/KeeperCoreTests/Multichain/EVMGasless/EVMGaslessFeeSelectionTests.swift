import BigInt
@testable import KeeperCore
import XCTest

/// How a fee method of an EVM transfer is listed and picked. What the fee is denominated in decides
/// who pays the chain: the chain's coin is paid by the wallet, battery charges and a same-chain
/// token by the relayer.
final class EVMGaslessFeeSelectionTests: XCTestCase {
    private let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: "")
    private let usdt = MultichainAssetDetails(assetId: GaslessFixtures.usdtId, name: "Tether", symbol: "USDT", decimals: 6, image: "")
    private let usdc = MultichainAssetDetails(assetId: GaslessFixtures.usdcId, name: "USD Coin", symbol: "USDC", decimals: 6, image: "")

    // MARK: - Routing

    func test_aFeeInTheChainCoinIsPaidByTheWallet() {
        let fee = native(amount: 5)

        XCTAssertTrue(fee.isNative)
        XCTAssertFalse(fee.isRelayed)
        XCTAssertFalse(fee.isBattery)
        XCTAssertEqual(fee.extraType, .multichain(token: eth))
        XCTAssertNil(fee.relayerAssetId)
    }

    func test_batteryChargesAreRelayed() {
        let fee = battery(charges: 3)

        XCTAssertTrue(fee.isBattery)
        XCTAssertTrue(fee.isRelayed)
        XCTAssertEqual(fee.extraType, .battery)
        XCTAssertEqual(fee.relayerAssetId, "battery/mainnet")
        guard case let .battery(charges, excess) = fee.extraValue else {
            return XCTFail("expected a battery value")
        }
        XCTAssertEqual(charges, 3)
        XCTAssertNil(excess)
    }

    func test_aFeeInATokenOfTheChainIsRelayed() {
        let fee = token(usdt, amount: 1)

        XCTAssertTrue(fee.isRelayed)
        XCTAssertFalse(fee.isBattery)
        XCTAssertFalse(fee.isNative)
        XCTAssertEqual(fee.extraType, .multichain(token: usdt))
        XCTAssertEqual(fee.relayerAssetId, GaslessFixtures.usdtId)
    }

    func test_aMethodThatCannotPayIsRenderedInsufficient() {
        XCTAssertFalse(battery(charges: 3).extraOption.isInsufficient)
        XCTAssertTrue(battery(charges: 3, insufficient: true).extraOption.isInsufficient)
        XCTAssertTrue(battery(charges: 3, available: false).extraOption.isInsufficient)
    }

    func test_pricingKeepsTheMethodAndChangesTheAmount() {
        XCTAssertEqual(battery(charges: 3).priced(19).payer, .battery(charges: 19))
        XCTAssertEqual(token(usdt, amount: 1).priced(123_433).payer, .token(usdt, fee: 123_433))
        XCTAssertEqual(native(amount: 5).priced(7).payer, .native(eth, fee: 7))
    }

    // MARK: - Resolve

    func test_nothingToResolveWithoutOptions() {
        XCTAssertNil(EVMGaslessFeeSelection.resolve([], picked: nil))
    }

    func test_theFirstPayableOptionWinsWithoutAPick() {
        let battery = battery(charges: 3)
        let native = native(amount: 5)

        XCTAssertEqual(EVMGaslessFeeSelection.resolve([battery, native], picked: nil), battery)
    }

    func test_aPayablePickWins() {
        let battery = battery(charges: 3)
        let native = native(amount: 5)

        XCTAssertEqual(EVMGaslessFeeSelection.resolve([battery, native], picked: native.extraType), native)
    }

    /// The pick comes from the picker's rows, the options from a later quote: here the row had the
    /// wallet's entry for USDC and the quote kept the relayer's, the contract in lowercase.
    func test_aPickNamesItsTokenWhateverElseDescribesIt() {
        let battery = battery(charges: 3)
        let gasless = token(usdc, amount: 1)
        let row = MultichainAssetDetails(
            assetId: "eth/mainnet/erc20/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            name: "USDC",
            symbol: "USDC",
            decimals: 6,
            image: "https://example.com/usdc.png",
            verification: .trusted
        )

        XCTAssertEqual(EVMGaslessFeeSelection.resolve([battery, gasless], picked: .multichain(token: row)), gasless)
    }

    func test_anInsufficientPickFallsBackToTheChainCoin() {
        let battery = battery(charges: 30, insufficient: true)
        let gasless = token(usdt, amount: 1)
        let native = native(amount: 5)

        // The coin is the method that always exists, so it beats another payable relayed method.
        XCTAssertEqual(EVMGaslessFeeSelection.resolve([battery, gasless, native], picked: .battery), native)
    }

    func test_withoutAPayableCoinAnyPayableMethodIsTaken() {
        let battery = battery(charges: 30, insufficient: true)
        let gasless = token(usdt, amount: 1)
        let native = native(amount: 50, insufficient: true)

        XCTAssertEqual(EVMGaslessFeeSelection.resolve([battery, gasless, native], picked: .battery), gasless)
    }

    func test_whenNothingIsPayableThePickStays() {
        let battery = battery(charges: 30, insufficient: true)
        let native = native(amount: 50, insufficient: true)

        XCTAssertEqual(EVMGaslessFeeSelection.resolve([battery, native], picked: native.extraType), native)
        XCTAssertEqual(EVMGaslessFeeSelection.resolve([battery, native], picked: nil), battery)
    }

    func test_anUnavailablePickHandsTheSelectionBackToTheHeadOfTheList() {
        let battery = battery(charges: 3)
        let native = native(amount: 5)
        let gasless = token(usdt, amount: 1, available: false)

        XCTAssertEqual(EVMGaslessFeeSelection.resolve([battery, native, gasless], picked: gasless.extraType), battery)
    }

    // MARK: - Priority

    func test_batteryLeadsThenTheCoinThenTheSentAssetThenAnyOther() {
        let battery = battery(charges: 3)
        let native = native(amount: 5)
        let sent = token(usdt, amount: 1)
        let other = token(usdc, amount: 1)

        let ordered = EVMGaslessFeeSelection.prioritize([other, sent, native, battery], sentAssetId: usdt.assetId.uppercased())

        XCTAssertEqual(ordered, [battery, native, sent, other])
    }

    func test_theSentAssetIsRecognisedUnderAnySpellingOfItsId() {
        let battery = battery(charges: 3)
        let sent = token(usdt, amount: 1)
        let other = token(usdc, amount: 1)

        let ordered = EVMGaslessFeeSelection.prioritize(
            [other, sent, battery],
            sentAssetId: "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7"
        )

        XCTAssertEqual(ordered, [battery, sent, other])
    }

    func test_methodsThatCannotPayAreListedLastInTheSameOrder() {
        let battery = battery(charges: 30, insufficient: true)
        let native = native(amount: 5)
        let sent = token(usdt, amount: 1, available: false)
        let other = token(usdc, amount: 1)

        let ordered = EVMGaslessFeeSelection.prioritize([other, sent, native, battery], sentAssetId: usdt.assetId)

        XCTAssertEqual(ordered, [native, other, battery, sent])
    }

    func test_aMethodRuledOutGoesBelowTheOnesThatCanPay() {
        let battery = battery(charges: 3)
        let native = native(amount: 5)
        let sent = token(usdt, amount: 1)

        let ruledOut = EVMGaslessFeeSelection.rulingOut(battery, in: [battery, native, sent])

        XCTAssertEqual(ruledOut.map(\.extraType), [native.extraType, sent.extraType, .battery])
        XCTAssertFalse(ruledOut[2].isAvailable)
        XCTAssertEqual(EVMGaslessFeeSelection.resolve(ruledOut, picked: .battery), native)
    }

    func test_replacingKeepsTheOrder() {
        let battery = battery(charges: 3)
        let native = native(amount: 5)

        let replaced = EVMGaslessFeeSelection.replacing(battery.priced(19), in: [native, battery])

        XCTAssertEqual(replaced, [native, battery.priced(19)])
    }

    // MARK: - Fixtures

    private func native(amount: BigUInt, insufficient: Bool = false) -> EVMGaslessFeeOption {
        EVMGaslessFeeOption(payer: .native(eth, fee: amount), relayerAssetId: nil, isInsufficient: insufficient)
    }

    private func token(
        _ asset: MultichainAssetDetails,
        amount: BigUInt,
        available: Bool = true,
        insufficient: Bool = false
    ) -> EVMGaslessFeeOption {
        EVMGaslessFeeOption(
            payer: .token(asset, fee: amount),
            relayerAssetId: asset.assetId,
            isAvailable: available,
            isInsufficient: insufficient
        )
    }

    private func battery(charges: Int, available: Bool = true, insufficient: Bool = false) -> EVMGaslessFeeOption {
        EVMGaslessFeeOption(
            payer: .battery(charges: charges),
            relayerAssetId: "battery/mainnet",
            isAvailable: available,
            isInsufficient: insufficient
        )
    }
}
