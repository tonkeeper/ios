import BigInt
@testable import KeeperCore
import TKBatteryAPI
import TonSwift
import XCTest

/// The fee methods of an Ethereum transfer: what the relayer's estimate turns into, in which order,
/// what emulating the selected one changes, and what the send checks before the relayer broadcasts.
final class EVMGaslessFeeEngineTests: XCTestCase {
    private let relayer = FakeRelayer()
    private let signer = FakeSigner()
    private var charges = BatteryChargesAvailability.available(100)
    private lazy var walletTokens = [walletToken(GaslessFixtures.usdcId, balance: 5_000_000)]
    private var tokenLookups = [[String]]()
    private var isEnabled = true
    private var batterySettings = BatterySettings()
    private var now = Date(timeIntervalSince1970: 1_790_000_000)

    /// Looks the wallet's tokens up the way the balance provider does: by what an id names, whatever
    /// its spelling, keyed by the id asked for.
    private lazy var engine = EVMGaslessFeeEngine(
        relayer: relayer,
        signer: signer,
        isEnabled: { [unowned self] _ in isEnabled },
        batteryCharges: { [unowned self] _ in charges },
        walletTokens: { [unowned self] assetIds, _ in
            tokenLookups.append(assetIds)
            return assetIds.reduce(into: [:]) { found, assetId in
                found[assetId] = walletTokens.first { AssetIdComponents.isSameAsset($0.asset.assetId, assetId) }
            }
        },
        now: { [unowned self] in now }
    )

    private let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: "")
    private let usdt = MultichainAssetDetails(assetId: GaslessFixtures.usdtId, name: "Tether", symbol: "USDT", decimals: 6, image: "")
    private let usdcAsset = Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdcId, name: "USDC", symbol: "USDC", decimals: 6, image: nil, chain: "eth")
    /// How the wallet API spells the USDC the relayer names in lowercase.
    private let walletUSDCId = "eth/mainnet/erc20/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    private let nativeFee = BigUInt("21672229775170")

    override func setUp() {
        super.setUp()
        relayer.estimations = [
            estimation(battery: 18),
            estimation(usdcAsset, fee: 115_304, available: false),
            estimation(usdtAsset, fee: 115_304),
        ]
        relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 19))
    }

    // MARK: - Estimate

    func test_aTokenTransferIsOfferedBatteryThenTheCoinThenTheTokenItself() async throws {
        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.options.map(\.relayerAssetId), [batteryId, nil, GaslessFixtures.usdtId, GaslessFixtures.usdcId])
        // Battery holds the selection, so it already carries the price of its emulation.
        XCTAssertEqual(quote.options.map(\.fee), [19, nativeFee, 115_304, 115_304])
        XCTAssertEqual(quote.options.map(\.canPay), [true, true, true, false])
        XCTAssertEqual(quote.options.map(\.isInsufficient), [false, false, false, false])
        XCTAssertEqual(quote.options.map(\.extraOption.isInsufficient), [false, false, false, true])
    }

    func test_aBatteryWithoutTheChargesIsListedLast() async throws {
        charges = .available(3)
        relayer.estimations = [
            estimation(battery: 18, available: false),
            estimation(usdcAsset, fee: 115_304, available: false),
            estimation(usdtAsset, fee: 115_304),
        ]

        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.options.map(\.relayerAssetId), [nil, GaslessFixtures.usdtId, batteryId, GaslessFixtures.usdcId])
        XCTAssertEqual(quote.options.map(\.canPay), [true, true, false, false])
        XCTAssertTrue(quote.options[2].isInsufficient)
    }

    func test_aFeeInTheSentTokenHasToFitNextToTheAmount() async throws {
        let quote = try await quoted(amount: 1_950_000)

        XCTAssertEqual(quote.options.map(\.relayerAssetId), [batteryId, nil, GaslessFixtures.usdtId, GaslessFixtures.usdcId])
        XCTAssertEqual(quote.options.map(\.canPay), [true, true, false, false])
        XCTAssertTrue(quote.options[2].isInsufficient)
    }

    /// 1.1 USDT in the wallet, 1 USDT sent, 0.5 USDT asked for the fee: the fee has to fit into the
    /// 0.1 USDT left after the transfer, not into the balance.
    func test_aFeeInTheSentTokenIsWeighedAgainstWhatTheTransferLeaves() async throws {
        relayer.estimations = [estimation(usdtAsset, fee: 500_000)]

        let quote = try await quoted(amount: 1_000_000, balance: 1_100_000)

        let usdtOption = try XCTUnwrap(quote.options.first { $0.relayerAssetId == GaslessFixtures.usdtId })
        XCTAssertTrue(usdtOption.isInsufficient)
        XCTAssertFalse(usdtOption.canPay)
        XCTAssertEqual(quote.selected(picked: .multichain(token: usdt))?.payer, .native(eth, fee: nativeFee))
    }

    /// The relayer spells the sent token's id its own way — a checksummed contract here — and the
    /// estimate still belongs to the asset being sent: weighed next to the amount, shown as it.
    func test_theSentTokenIsRecognisedUnderTheRelayersSpelling() async throws {
        let checksummedId = "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7"
        relayer.estimations = [
            estimation(
                Components.Schemas.GaslessV2Asset(id: checksummedId, name: "Tether USD", symbol: "USDT", decimals: 6, image: nil, chain: "eth"),
                fee: 500_000
            ),
        ]
        // Were it taken for another token, this balance would make the fee look payable.
        walletTokens.append(walletToken(checksummedId, symbol: "USDT", balance: 5_000_000))

        let quote = try await quoted(amount: 1_000_000, balance: 1_100_000)

        let usdtOption = try XCTUnwrap(quote.options.first { $0.relayerAssetId == checksummedId })
        XCTAssertEqual(usdtOption.extraType, .multichain(token: usdt))
        XCTAssertTrue(usdtOption.isInsufficient)
    }

    func test_anotherTokenOfTheWalletCanPay() async throws {
        relayer.estimations = relayer.estimations.map { EVMGaslessEstimation(asset: $0.asset, fee: $0.fee, isAvailable: true) }

        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.options.map(\.relayerAssetId), [batteryId, nil, GaslessFixtures.usdtId, GaslessFixtures.usdcId])
        XCTAssertTrue(quote.options.allSatisfy(\.canPay))
    }

    /// The relayer's own word that the wallet can afford a fee is not enough: a balance the wallet
    /// cannot read cannot cover anything.
    func test_aTokenWhoseBalanceCannotBeReadCannotPay() async throws {
        walletTokens = []
        relayer.estimations = relayer.estimations.map { EVMGaslessEstimation(asset: $0.asset, fee: $0.fee, isAvailable: true) }

        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.options.last?.relayerAssetId, GaslessFixtures.usdcId)
        XCTAssertTrue(quote.options.last?.isInsufficient == true)
    }

    /// Every lookup can page through a listing of thousands of assets: the tokens the relayer takes
    /// are read in one go, and the sent token and the ones it rules out are not read at all.
    func test_theTokensTheRelayerTakesAreLookedUpOnce() async throws {
        let dai = Components.Schemas.GaslessV2Asset(
            id: "eth/mainnet/erc20/0x6b175474e89094c44da98b954eedeac495271d0f", name: "Dai", symbol: "DAI", decimals: 18, image: nil, chain: "eth"
        )
        let pepe = Components.Schemas.GaslessV2Asset(
            id: "eth/mainnet/erc20/0x6982508145454ce325ddbe47a25d4ec3d2311933", name: "Pepe", symbol: "PEPE", decimals: 18, image: nil, chain: "eth"
        )
        relayer.estimations = [
            estimation(battery: 18),
            estimation(usdcAsset, fee: 115_304),
            estimation(dai, fee: 115_304),
            estimation(pepe, fee: 115_304, available: false),
            estimation(usdtAsset, fee: 115_304),
        ]

        _ = try await quoted(amount: 1_000_000)

        XCTAssertEqual(tokenLookups, [[GaslessFixtures.usdcId, dai.id]])
    }

    /// The relayer spells USDC in lowercase where the wallet checksums it: the row, the pick and the
    /// deposit go by the wallet's entry, and the relayer is still asked in its own spelling.
    func test_anotherTokenGoesByTheWalletsEntryForIt() async throws {
        let usdc = walletToken(walletUSDCId, balance: 5_000_000)
        walletTokens = [usdc]
        relayer.estimations = [estimation(usdcAsset, fee: 115_304)]
        relayer.emulations[GaslessFixtures.usdcId] = .success(emulation(assetId: GaslessFixtures.usdcId, fee: 115_304))

        let quote = try await quoted(amount: 1_000_000, picked: .multichain(token: usdc.asset))

        let usdcOption = try XCTUnwrap(quote.options.first { $0.relayerAssetId == GaslessFixtures.usdcId })
        XCTAssertEqual(usdcOption.extraType, .multichain(token: usdc.asset))
        XCTAssertTrue(usdcOption.canPay)
        XCTAssertEqual(quote.emulation?.assetId, GaslessFixtures.usdcId)
        XCTAssertEqual(relayer.emulated, [GaslessFixtures.usdcId])
    }

    func test_aCoinThatCannotCoverItsOwnFeeGoesBelowTheRelayedMethods() async throws {
        let quote = try await quoted(amount: 1_000_000, nativeInsufficient: true)

        XCTAssertEqual(quote.options.map(\.relayerAssetId), [batteryId, GaslessFixtures.usdtId, nil, GaslessFixtures.usdcId])
        XCTAssertEqual(quote.options.map(\.canPay), [true, true, false, false])
    }

    func test_aMaxCoinTransferIsRelayedWhole() async throws {
        let balance: BigUInt = 390_727_718_715_115
        relayer.estimations = [
            estimation(battery: 18),
            estimation(ethAsset, fee: 21000),
            estimation(usdcAsset, fee: 115_304),
        ]

        let quote = try await quoted(amount: balance, balance: balance, of: eth)

        XCTAssertEqual(quote.call.value, balance)
        XCTAssertEqual(quote.options.map(\.relayerAssetId), [batteryId, nil, GaslessFixtures.usdcId, ethAsset.id])
        XCTAssertEqual(quote.options.map(\.canPay), [true, true, true, false])
        XCTAssertEqual(quote.selected(picked: nil)?.payer, .battery(charges: 19))
    }

    /// The relayer is asked to carry the transfer the screen confirms, comment included.
    func test_aCoinTransfersCommentIsRelayedWithIt() async {
        let quote = await engine.estimate(transfer(amount: 1000, of: eth, comment: "hi"))

        XCTAssertEqual(quote?.call.data, "0x6869")
    }

    func test_anEstimateThatFailsKeepsThePlainFee() async {
        relayer.estimateError = URLError(.badServerResponse)

        let quote = await engine.estimate(transfer(amount: 1_000_000))

        XCTAssertNil(quote)
    }

    func test_aRelayerTurnedOffOffersNothing() async {
        isEnabled = false

        let quote = await engine.estimate(transfer(amount: 1_000_000))

        XCTAssertNil(quote)
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    /// The wallet's own battery switch for token transfers covers EVM transfers too: a user who
    /// turned it off is not offered a relayed fee, whatever the remote flags say.
    func test_aWalletThatTurnedBatteryOffForTokensIsOfferedNothing() async {
        batterySettings = BatterySettings(isJettonTransactionEnable: false)

        let quote = await engine.estimate(transfer(amount: 1_000_000))

        XCTAssertNil(quote)
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    func test_theWalletsSwapSwitchDoesNotGovernATransfer() async throws {
        batterySettings = BatterySettings(isSwapTransactionEnable: false)

        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.options.first?.relayerAssetId, batteryId)
    }

    func test_aBatteryPriceOfZeroChargesIsNotAMethod() async throws {
        relayer.estimations = [estimation(battery: 0), estimation(usdtAsset, fee: 115_304)]

        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.options.map(\.relayerAssetId), [nil, GaslessFixtures.usdtId])
    }

    // MARK: - Quote

    func test_theSelectedMethodIsPricedByItsEmulation() async throws {
        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.emulation?.assetId, batteryId)
        XCTAssertEqual(quote.selected(picked: nil)?.payer, .battery(charges: 19))
        XCTAssertEqual(quote.options.first { $0.relayerAssetId == GaslessFixtures.usdtId }?.fee, 115_304)
        XCTAssertEqual(relayer.emulated, [batteryId])
    }

    func test_aPickedTokenIsEmulatedUnderTheRelayersAssetId() async throws {
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: 123_433))

        let quote = try await quoted(amount: 1_000_000, picked: .multichain(token: usdt))

        XCTAssertEqual(quote.emulation?.assetId, GaslessFixtures.usdtId)
        XCTAssertEqual(quote.selected(picked: .multichain(token: usdt))?.payer, .token(usdt, fee: 123_433))
        XCTAssertEqual(relayer.emulated, [GaslessFixtures.usdtId])
    }

    /// The pick is made from the picker's rows, and every quote looks the wallet's tokens up again:
    /// a token the wallet describes otherwise this time is still the one picked.
    func test_aPickedTokenHoldsWhenTheWalletDescribesItOtherwise() async throws {
        let row = MultichainAssetDetails(assetId: walletUSDCId, name: "USD Coin", symbol: "USDC", decimals: 6, image: "https://example.com/usdc.png")
        walletTokens = [walletToken(walletUSDCId, balance: 5_000_000)]
        relayer.estimations = [estimation(battery: 18), estimation(usdcAsset, fee: 115_304)]
        relayer.emulations[GaslessFixtures.usdcId] = .success(emulation(assetId: GaslessFixtures.usdcId, fee: 123_433))

        let quote = try await quoted(amount: 1_000_000, picked: .multichain(token: row))

        XCTAssertEqual(relayer.emulated, [GaslessFixtures.usdcId])
        XCTAssertEqual(quote.emulation?.assetId, GaslessFixtures.usdcId)
        XCTAssertEqual(quote.selected(picked: .multichain(token: row))?.fee, 123_433)
    }

    func test_anEmulationThatFailsRulesTheMethodOut() async throws {
        relayer.emulations[batteryId] = .failure(URLError(.badServerResponse))

        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.options.map(\.relayerAssetId), [nil, GaslessFixtures.usdtId, batteryId, GaslessFixtures.usdcId])
        XCTAssertEqual(quote.selected(picked: nil)?.payer, .native(eth, fee: nativeFee))
        XCTAssertNil(quote.emulation)
    }

    func test_anEmulatedPriceTheBalanceCannotCoverHandsTheSelectionOn() async throws {
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: 1_100_000))

        let quote = try await quoted(amount: 1_000_000, picked: .multichain(token: usdt))

        XCTAssertEqual(relayer.emulated, [GaslessFixtures.usdtId, batteryId])
        XCTAssertEqual(quote.options.map(\.relayerAssetId), [batteryId, nil, GaslessFixtures.usdtId, GaslessFixtures.usdcId])
        XCTAssertEqual(quote.emulation?.assetId, batteryId)
        XCTAssertEqual(quote.selected(picked: .multichain(token: usdt))?.payer, .battery(charges: 19))
    }

    func test_theChainCoinIsNeverQuoted() async throws {
        let quote = try await quoted(amount: 1_000_000, picked: .multichain(token: eth))

        XCTAssertTrue(relayer.emulated.isEmpty)
        XCTAssertNil(quote.emulation)
        XCTAssertEqual(quote.selected(picked: .multichain(token: eth))?.payer, .native(eth, fee: nativeFee))
    }

    // MARK: - Reweigh

    /// The picker can open long after the quote: a battery charged since then reads as payable, in
    /// the place the quote listed it.
    func test_aBalanceThatMovedSinceTheQuoteIsWeighedAgain() async throws {
        charges = .available(3)
        let quote = try await quoted(amount: 1_000_000)
        charges = .available(100)

        let options = await engine.reweighed(quote.options, transfer: transfer(amount: 1_000_000))

        XCTAssertEqual(quote.options.map(\.canPay), [true, true, false, false])
        XCTAssertEqual(options.map(\.relayerAssetId), [nil, GaslessFixtures.usdtId, batteryId, GaslessFixtures.usdcId])
        XCTAssertEqual(options.map(\.canPay), [true, true, true, false])
    }

    // MARK: - Send

    func test_theQuotedOperationIsSignedAndHandedToTheRelayer() async throws {
        let quote = try await quoted(amount: 1_000_000)

        let result = await send(quote)

        XCTAssertNil(failure(of: result))
        XCTAssertEqual(signer.signed.map(\.id), ["bcef74e1-b940-4142-b7a7-76161850971e"])
        XCTAssertEqual(relayer.sent, [FakeSigner.signature])
        XCTAssertEqual(relayer.emulated, [batteryId])
    }

    func test_anExpiredEmulationIsQuotedAgainBeforeSending() async throws {
        let quote = try await quoted(amount: 1_000_000)
        now = now.addingTimeInterval(20 * 60)

        let result = await send(quote)

        XCTAssertNil(failure(of: result))
        XCTAssertEqual(relayer.emulated, [batteryId, batteryId])
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_aFeeTheBalanceNoLongerCoversIsNotSent() async throws {
        let quote = try await quoted(amount: 1_000_000)
        charges = .available(5)

        let result = await send(quote)

        guard case .multichainTransactionFailure(.insufficientSelectedFee)? = failure(of: result) else {
            return XCTFail("expected the insufficient fee failure, got \(String(describing: failure(of: result)))")
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aDismissedPasscodePromptCancelsTheSend() async throws {
        let quote = try await quoted(amount: 1_000_000)
        signer.failure = .canceled

        let result = await send(quote)

        guard case .cancelledByUser? = failure(of: result) else {
            return XCTFail("expected a cancellation, got \(String(describing: failure(of: result)))")
        }
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aRelayerThatForgotTheOperationFailsTheSend() async throws {
        let quote = try await quoted(amount: 1_000_000)
        relayer.sendError = EVMGaslessRelayerError.quoteExpired

        let result = await send(quote)

        guard case .multichainTransactionFailure(.relayerQuoteExpired)? = failure(of: result) else {
            return XCTFail("expected an expired quote failure, got \(String(describing: failure(of: result)))")
        }
    }

    func test_aRelayerRefusalFailsTheSend() async throws {
        let quote = try await quoted(amount: 1_000_000)
        relayer.sendError = EVMGaslessRelayerError.rejected(reason: "invalid_signature")

        let result = await send(quote)

        guard case .multichainTransactionFailure(.relayerRejected)? = failure(of: result) else {
            return XCTFail("expected a rejection, got \(String(describing: failure(of: result)))")
        }
    }

    /// A relayer that did not answer may have broadcast the transfer: the send must not read as refused.
    func test_aRelayerThatDidNotAnswerLeavesTheOutcomeUnknown() async throws {
        let quote = try await quoted(amount: 1_000_000)
        relayer.sendError = URLError(.timedOut)

        let result = await send(quote)

        guard case .multichainTransactionFailure(.relayerOutcomeUnknown)? = failure(of: result) else {
            return XCTFail("expected an unknown outcome, got \(String(describing: failure(of: result)))")
        }
    }

    func test_aQuoteThatCannotBeRenewedFailsTheSend() async throws {
        let quote = try await quoted(amount: 1_000_000)
        now = now.addingTimeInterval(20 * 60)
        relayer.emulations[batteryId] = .failure(URLError(.badServerResponse))

        let result = await send(quote)

        guard case .multichainTransactionFailure(.relayerQuoteUnavailable)? = failure(of: result) else {
            return XCTFail("expected an unavailable quote failure, got \(String(describing: failure(of: result)))")
        }
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    // MARK: - Helpers

    private var batteryId: String {
        "battery/mainnet"
    }

    private var ethAsset: Components.Schemas.GaslessV2Asset {
        Components.Schemas.GaslessV2Asset(id: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: nil, chain: "eth")
    }

    private var usdtAsset: Components.Schemas.GaslessV2Asset {
        Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdtId, name: "USDT", symbol: "USDT", decimals: 6, image: nil, chain: "eth")
    }

    private func walletToken(_ assetId: String, symbol: String = "USDC", balance: BigUInt) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(assetId: assetId, name: symbol, symbol: symbol, decimals: 6, image: ""),
            price: .init(prices: [:], diff24h: [:], diff7d: [:]),
            balance: balance
        )
    }

    /// Estimates and quotes the way the confirmation controller does: the chain's own fee from
    /// ChainKit is put next to the relayed methods before the selected one is emulated.
    private func estimate(
        amount: BigUInt,
        balance: BigUInt = 2_006_121,
        of asset: MultichainAssetDetails? = nil,
        picked: TransactionConfirmationModel.ExtraType? = nil,
        nativeInsufficient: Bool = false
    ) async -> EVMGaslessFeeEngine.Quote? {
        let transfer = transfer(amount: amount, balance: balance, of: asset)
        guard var quote = await engine.estimate(transfer) else {
            return nil
        }
        quote.options.append(
            EVMGaslessFeeOption(payer: .native(eth, fee: nativeFee), relayerAssetId: nil, isInsufficient: nativeInsufficient)
        )
        return await engine.quote(quote, picked: picked, transfer: transfer)
    }

    private func quoted(
        amount: BigUInt,
        balance: BigUInt = 2_006_121,
        of asset: MultichainAssetDetails? = nil,
        picked: TransactionConfirmationModel.ExtraType? = nil,
        nativeInsufficient: Bool = false
    ) async throws -> EVMGaslessFeeEngine.Quote {
        let quote = await estimate(amount: amount, balance: balance, of: asset, picked: picked, nativeInsufficient: nativeInsufficient)
        return try XCTUnwrap(quote)
    }

    private func send(_ quote: EVMGaslessFeeEngine.Quote) async -> Result<Void, TransactionConfirmationError> {
        let selected = quote.selected(picked: nil)!
        return await engine.send(quote, selected: selected, transfer: transfer(amount: 1_000_000), passcodeProvider: { "passcode" })
    }

    private func failure(of result: Result<Void, TransactionConfirmationError>) -> TransactionConfirmationError? {
        guard case let .failure(error) = result else {
            return nil
        }
        return error
    }

    private func transfer(
        amount: BigUInt,
        balance: BigUInt = 2_006_121,
        of asset: MultichainAssetDetails? = nil,
        comment: String? = nil
    ) -> EVMGaslessFeeEngine.Transfer {
        EVMGaslessFeeEngine.Transfer(
            wallet: wallet,
            chain: .eth,
            asset: MultichainAsset(
                asset: asset ?? usdt,
                price: .init(prices: [:], diff24h: [:], diff7d: [:]),
                balance: balance
            ),
            amount: amount,
            recipient: GaslessFixtures.sender,
            comment: comment
        )
    }

    private func estimation(battery charges: BigUInt, available: Bool = true) -> EVMGaslessEstimation {
        EVMGaslessEstimation(
            asset: Components.Schemas.GaslessV2Asset(id: batteryId, name: "Battery", symbol: "BATTERY", decimals: 0, image: nil, chain: nil),
            fee: charges,
            isAvailable: available
        )
    }

    private func estimation(_ asset: Components.Schemas.GaslessV2Asset, fee: BigUInt, available: Bool = true) -> EVMGaslessEstimation {
        EVMGaslessEstimation(asset: asset, fee: fee, isAvailable: available)
    }

    private func emulation(assetId: String, fee: BigUInt) -> EVMGaslessEmulation {
        EVMGaslessEmulation(
            assetId: assetId,
            fee: fee,
            operation: try! MultichainRelayedOperation(
                id: "bcef74e1-b940-4142-b7a7-76161850971e",
                json: GaslessFixtures.operation(feeAssetId: assetId, fee: fee.description)
            ),
            expiresAt: now.addingTimeInterval(10 * 60)
        )
    }

    private var wallet: Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: batterySettings,
            multichain: .multichain(
                .init(
                    walletId: "multichain-wallet-id",
                    addresses: [.init(chain: .eth, address: GaslessFixtures.sender)]
                )
            )
        )
    }
}

private final class FakeRelayer: EVMGaslessRelaying {
    var estimations = [EVMGaslessEstimation]()
    var estimateError: Error?
    var estimateCalls = 0
    var emulations = [String: Result<EVMGaslessEmulation, Error>]()
    var emulated = [String]()
    var sent = [Data]()
    var sendError: Error?

    func estimate(wallet _: Wallet, call _: EVMGaslessCall) async throws -> [EVMGaslessEstimation] {
        estimateCalls += 1
        if let estimateError {
            throw estimateError
        }
        return estimations
    }

    func emulate(wallet _: Wallet, call _: EVMGaslessCall, assetId: String) async throws -> EVMGaslessEmulation {
        emulated.append(assetId)
        guard let result = emulations[assetId] else {
            throw EVMGaslessRelayerError.rejected(reason: "no emulation for \(assetId)")
        }
        return try result.get()
    }

    func send(wallet _: Wallet, signedOperation: Data) async throws {
        if let sendError {
            throw sendError
        }
        sent.append(signedOperation)
    }
}

private final class FakeSigner: MultichainRelayedOperationSigner {
    static let signature = Data("signed".utf8)

    var signed = [MultichainRelayedOperation]()
    var failure: MultichainTransactionFailure?

    func signRelayedOperation(
        passcodeProvider _: @escaping () async -> String?,
        wallet _: Wallet,
        chain _: MultichainChain,
        operation: MultichainRelayedOperation
    ) async throws(MultichainTransactionFailure) -> Data {
        if let failure {
            throw failure
        }
        signed.append(operation)
        return Self.signature
    }
}
