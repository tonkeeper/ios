import BigInt
import ChainKit
@testable import KeeperCore
import OperationReviewModels
import TKBatteryAPI
import TonSwift
import XCTest

/// The fee methods of an Ethereum transfer: what the relayer's estimate turns into, in which order,
/// what emulating the selected one changes, and what the send checks before the relayer broadcasts.
final class EVMGaslessFeeEngineTests: XCTestCase {
    private let relayer = FakeRelayer()
    private let signer = FakeSigner()
    private var charges = BatteryChargesAvailability.available(100)
    private var paymentCharges: BatteryChargesAvailability?
    private var migrationPending = false
    private lazy var walletTokens = [walletToken(GaslessFixtures.usdcId, balance: 5_000_000)]
    private var tokenLookups = [[String]]()
    private var isEnabled = true
    private var batterySettings = BatterySettings()
    private let clock = PaymentClock(Date(timeIntervalSince1970: 1_790_000_000))
    /// What the send gate checks; registered before the engine is first used.
    private var checks = [any OperationCheck]()
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

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
        gate: OperationGate { [checks] in checks },
        now: { [clock] in clock.now },
        currentBatteryCharges: { [unowned self] _ in paymentCharges ?? charges },
        offersBatteryMigration: { [unowned self] _ in migrationPending }
    )

    private let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: "")
    private let usdt = MultichainAssetDetails(assetId: GaslessFixtures.usdtId, name: "Tether", symbol: "USDT", decimals: 6, image: "")
    private let usdcAsset = Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdcId, name: "USDC", symbol: "USDC", decimals: 6, image: nil)
    /// How the wallet API spells the USDC the relayer names in lowercase.
    private let walletUSDCId = "eth/mainnet/erc20/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    /// Someone other than the sender, so a review can tell the two apart.
    private let recipient = "0x8ba1f109551bd432803012645ac136ddd64dba72"
    private let sol = MultichainAssetDetails(assetId: "sol/mainnet/coin", name: "Solana", symbol: "SOL", decimals: 9, image: "")
    private let solanaSender = "9wFFyRfZBsuAha4YcuxcXLKwMxJR43S7fPfQLusDBzvT"
    private let nativeFee = BigUInt("21672229775170")

    override func setUp() {
        super.setUp()
        relayer.estimations = [
            estimation(battery: 18),
            estimation(usdcAsset, fee: 115_304, available: false),
            estimation(usdtAsset, fee: 115_304),
        ]
        relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 19))
        relayer.now = { [clock] in clock.now }
    }

    // MARK: - Estimate

    func test_legacyBatteryCanBePickedBeforeMigrationWithoutEmulatingAnUnfundedAccount() async throws {
        migrationPending = true
        charges = .unknown
        paymentCharges = .available(0)
        relayer.estimations = [estimation(battery: 18, available: false)]

        let quote = try await quoted(amount: 1_000_000, picked: .battery)

        XCTAssertEqual(quote.selected(picked: .battery)?.payer, .battery(charges: 18))
        XCTAssertEqual(quote.selected(picked: .battery)?.canPay, true)
        XCTAssertNil(quote.emulation)
        XCTAssertTrue(relayer.emulated.isEmpty)
    }

    func test_previewBalanceCannotAuthorizeASendBeforeMigration() async throws {
        migrationPending = true
        charges = .unknown
        paymentCharges = .available(0)
        relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 18))
        let quote = try await quoted(amount: 1_000_000, picked: .battery)

        let result = await send(quote, picked: .battery)

        guard case .failure(.multichainTransactionFailure(.insufficientSelectedFee)) = result else {
            return XCTFail("Expected the actual balance to stop the send: \(result)")
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aTokenTransferIsOfferedBatteryThenTheCoinThenTheTokenItself() async throws {
        let quote = try await quoted(amount: 1_000_000)

        XCTAssertEqual(quote.options.map(\.relayerAssetId), [batteryId, nil, GaslessFixtures.usdtId, GaslessFixtures.usdcId])
        // Battery holds the selection, so it already carries the price of its emulation.
        XCTAssertEqual(quote.options.map(\.fee), [19, nativeFee, 115_304, 115_304])
        XCTAssertEqual(quote.options.map(\.canPay), [true, true, true, false])
        XCTAssertEqual(quote.options.map(\.isInsufficient), [false, false, false, false])
        XCTAssertEqual(quote.options.map(\.extraOption.isInsufficient), [false, false, false, false])
        XCTAssertEqual(quote.options.map(\.extraOption.isAvailable), [true, true, true, false])
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
                Components.Schemas.GaslessV2Asset(id: checksummedId, name: "Tether USD", symbol: "USDT", decimals: 6, image: nil),
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
            id: "eth/mainnet/erc20/0x6b175474e89094c44da98b954eedeac495271d0f", name: "Dai", symbol: "DAI", decimals: 18, image: nil
        )
        let pepe = Components.Schemas.GaslessV2Asset(
            id: "eth/mainnet/erc20/0x6982508145454ce325ddbe47a25d4ec3d2311933", name: "Pepe", symbol: "PEPE", decimals: 18, image: nil
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

    /// A switch stored before the battery settings screen was removed no longer turns the battery off.
    func test_storedBatterySwitchesAreIgnored() async throws {
        batterySettings = BatterySettings(isSwapTransactionEnable: false, isJettonTransactionEnable: false)

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

    func test_anOperationOfOtherCallsThanTheTransferIsNotSigned() async throws {
        let foreign = "0x000000000000000000000000000000000000dead"
        let quote = try await quoted(amount: 1_000_000)
        relayer.buildsAskedCalls = false
        let others: [[(target: String, data: String)]] = try [
            [(GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: foreign, amount: 1_000_000)))],
            [
                (GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: recipient, amount: 1_000_000))),
                (GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: foreign, amount: 1_000_000))),
            ],
        ]
        for calls in others {
            var expired = try XCTUnwrap(quote.emulation)
            expired = EVMGaslessEmulation(assetId: expired.assetId, fee: expired.fee, operation: expired.operation, expiresAt: clock.now)
            var stale = quote
            stale.emulation = expired
            relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 19, calls: calls, deadline: clock.now.addingTimeInterval(600)))

            let result = await send(stale)

            assertQuoteUnavailable(result)
            var unpriced = quote
            unpriced.emulation = nil
            let requoted = await engine.quote(unpriced, picked: nil, transfer: transfer(amount: 1_000_000))
            XCTAssertNil(requoted.emulation)
            XCTAssertNotEqual(requoted.selected(picked: nil)?.relayerAssetId, batteryId)
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_anExpiredEmulationIsQuotedAgainBeforeSending() async throws {
        let quote = try await quoted(amount: 1_000_000)
        clock.advance(by: 20 * 60)
        relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 19))

        let result = await send(quote)

        XCTAssertNil(failure(of: result))
        XCTAssertEqual(relayer.emulated, [batteryId, batteryId])
        XCTAssertEqual(relayer.sent.count, 1)
    }

    /// A Solana operation carries a recent blockhash that lapses well before the relayer's deadline,
    /// so the emulation the review showed is priced again however live it reads.
    func test_aLiveSolanaEmulationIsQuotedAgainAfterThePasscode() async throws {
        let (transfer, quote) = try await quotedSolanaTransfer()
        XCTAssertEqual(quote.emulation?.assetId, batteryId)
        clock.advance(by: 40)
        let fresh = emulation(assetId: batteryId, fee: 18)

        let selected = try XCTUnwrap(quote.selected(picked: nil))
        let result = await engine.send(
            quote,
            selected: selected,
            transfer: transfer,
            passcodeProvider: {
                XCTAssertEqual(self.relayer.emulated, [self.batteryId])
                self.relayer.emulations[self.batteryId] = .success(fresh)
                return "passcode"
            },
            consent: .refuse
        )

        XCTAssertNil(failure(of: result))
        XCTAssertEqual(relayer.emulated, [batteryId, batteryId])
        XCTAssertEqual(signer.signed.map(\.json), [fresh.operation.json])
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_aPossiblyBroadcastSolanaTransferLeavesTheOutcomeUnknown() async throws {
        let (transfer, quote) = try await quotedSolanaTransfer()
        let selected = try XCTUnwrap(quote.selected(picked: nil))
        relayer.sendError = EVMGaslessRelayerError.rejected(reason: "broadcast_failed", mayHaveBroadcast: true)

        let result = await engine.send(
            quote,
            selected: selected,
            transfer: transfer,
            passcodeProvider: { "passcode" },
            consent: .refuse
        )

        guard case .multichainTransactionFailure(.relayerOutcomeUnknown)? = failure(of: result) else {
            return XCTFail("expected an unknown outcome, got \(String(describing: failure(of: result)))")
        }
    }

    /// A device whose clock runs past the relayer's reads the operation it is just handed as expired:
    /// that is left to the relayer to judge, as it always was, rather than quoted again on every swipe.
    func test_anOperationTheDeviceClockReadsAsExpiredAlreadyIsStillSent() async throws {
        let quote = try await quoted(amount: 1_000_000)
        clock.advance(by: 20 * 60)

        let result = await send(quote)

        XCTAssertNil(failure(of: result))
        XCTAssertEqual(relayer.emulated, [batteryId, batteryId])
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_anOperationWhoseDeadlineTheDeviceClockHasPassedIsStillSent() async throws {
        let quote = try await quoted(amount: 1_000_000)
        let relayersNow = clock.now
        relayer.now = { relayersNow }
        clock.advance(by: 20 * 60)

        let result = await send(quote)

        XCTAssertNil(failure(of: result))
        XCTAssertEqual(relayer.sent.count, 1)
    }

    /// 30 charges asked for on the second emulation are not the 19 confirmed: the relayer's quote
    /// is refused, so the screen quotes the transfer again.
    func test_aReEmulatedFeeAboveTheConfirmedOneIsNotSigned() async throws {
        let quote = try await quoted(amount: 1_000_000)
        clock.advance(by: 20 * 60)
        relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 30))

        let result = await send(quote)

        assertQuoteUnavailable(result)
        XCTAssertEqual(quote.emulation?.fee, 19)
        XCTAssertEqual(relayer.emulated, [batteryId, batteryId])
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    /// 25 charges cover the 19 confirmed but not the 30 asked for: the new price is refused before
    /// the balance is weighed, so the screen quotes it again instead of reporting the old one short.
    func test_aReEmulatedFeeTheBalanceCannotCoverIsRefusedForItsPrice() async throws {
        let quote = try await quoted(amount: 1_000_000)
        clock.advance(by: 20 * 60)
        relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 30))
        charges = .available(25)

        let result = await send(quote)

        assertQuoteUnavailable(result)
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aReEmulatedFeeAtOrBelowTheConfirmedOneIsSigned() async throws {
        for charges: BigUInt in [19, 15] {
            relayer.buildsAskedCalls = true
            let quote = try await quoted(amount: 1_000_000)
            clock.advance(by: 20 * 60)
            relayer.buildsAskedCalls = false
            let requoted = emulation(assetId: batteryId, fee: charges, calls: askedTransfer)
            relayer.emulations[batteryId] = .success(requoted)

            let result = await send(quote)

            XCTAssertNil(failure(of: result), "\(charges)")
            XCTAssertEqual(signer.signed.last?.json, requoted.operation.json, "\(charges)")
            relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 19))
        }
        XCTAssertEqual(relayer.sent.count, 2)
    }

    /// A fee in a token follows its rate: 120 000 is within 5% of the 115 304 confirmed.
    func test_aReEmulatedTokenFeeWithinTheToleranceIsSigned() async throws {
        let quote = try await quotedInUSDT(fee: 115_304, balance: 2_006_121)
        clock.advance(by: 20 * 60)
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: 120_000))

        let result = await send(quote, picked: .multichain(token: usdt), balance: 2_006_121)

        XCTAssertNil(failure(of: result))
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_aReEmulatedTokenFeePastTheToleranceIsNotSigned() async throws {
        let quote = try await quotedInUSDT(fee: 115_304, balance: 2_006_121)
        clock.advance(by: 20 * 60)
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: 121_070))

        let result = await send(quote, picked: .multichain(token: usdt), balance: 2_006_121)

        assertQuoteUnavailable(result)
        XCTAssertTrue(signer.signed.isEmpty)
    }

    /// 1.118 USDT pays the 1 USDT sent with the 0.115304 confirmed, not with the 0.12 the relayer asks
    /// for now — a price the tolerance lets through, so only the balance is left to stop it.
    func test_aReEmulatedTokenFeeWithinTheToleranceTheBalanceCannotCoverIsNotSent() async throws {
        let quote = try await quotedInUSDT(fee: 115_304, balance: 1_118_000)
        clock.advance(by: 20 * 60)
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: 120_000))

        let result = await send(quote, picked: .multichain(token: usdt), balance: 1_118_000)

        guard case .multichainTransactionFailure(.insufficientSelectedFee)? = failure(of: result) else {
            return XCTFail("expected the insufficient fee failure, got \(String(describing: failure(of: result)))")
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
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
        clock.advance(by: 20 * 60)
        relayer.emulations[batteryId] = .failure(URLError(.badServerResponse))

        let result = await send(quote)

        guard case .multichainTransactionFailure(.relayerQuoteUnavailable)? = failure(of: result) else {
            return XCTFail("expected an unavailable quote failure, got \(String(describing: failure(of: result)))")
        }
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    // MARK: - Review

    func test_withoutChecksNothingIsReviewedAndARefusingConsentStillSends() async throws {
        let quote = try await quoted(amount: 1_000_000)

        let result = await send(quote, consent: .refuse)

        XCTAssertNil(quote.review)
        XCTAssertNil(failure(of: result))
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_aBatteryFeeIsReviewedOnTheQuoteAndARefusalSignsNothing() async throws {
        checks = [WarningCheck()]
        let quote = try await quoted(amount: 1_000_000)
        let user = ConsentingUser(answering: false)

        let result = await send(quote, consent: user.attempt())

        guard case .cancelledByUser? = failure(of: result) else {
            return XCTFail("expected a cancellation, got \(String(describing: failure(of: result)))")
        }
        let review = try XCTUnwrap(quote.review)
        XCTAssertEqual(review.severity, .warning)
        let asked = await user.asked
        XCTAssertEqual(asked, [review])
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_theOperationAcceptedOnTheSwipeIsSignedWithoutAskingAgain() async throws {
        checks = [WarningCheck()]
        let quote = try await quoted(amount: 1_000_000)
        let user = ConsentingUser(answering: true)
        let consent = user.attempt()
        let accepted = try await consent(XCTUnwrap(quote.review))

        let result = await send(quote, consent: consent)

        XCTAssertTrue(accepted)
        XCTAssertNil(failure(of: result))
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(relayer.sent.count, 1)
    }

    /// A quote that expired is emulated again into another operation: what the swipe accepted does
    /// not cover it.
    func test_anOperationEmulatedAgainIsAskedAboutAgain() async throws {
        checks = [WarningCheck()]
        let quote = try await quoted(amount: 1_000_000)
        let user = ConsentingUser(answering: true)
        let consent = user.attempt()
        _ = try await consent(XCTUnwrap(quote.review))
        clock.advance(by: 20 * 60)
        relayer.buildsAskedCalls = false
        let requoted = emulation(assetId: batteryId, fee: 15, calls: askedTransfer)
        relayer.emulations[batteryId] = .success(requoted)

        let result = await send(quote, consent: consent)

        XCTAssertNil(failure(of: result))
        let asked = await user.asked
        XCTAssertEqual(asked.count, 2)
        XCTAssertNotEqual(asked.first?.id, asked.last?.id)
        XCTAssertEqual(signer.signed.map(\.json), [requoted.operation.json])
    }

    /// Until the relayer's operation states its fee, a fee in a token would be read as a payment to
    /// someone else: it is logged and never asked about.
    func test_aTokenFeeIsOnlyLoggedAndTheTransferGoesOn() async throws {
        checks = [WarningCheck()]
        let log = RecordedLog()
        defer { log.stop() }
        let quote = try await quotedInUSDT(fee: 115_304, balance: 2_006_121)
        let user = ConsentingUser(answering: false)

        let result = await send(quote, picked: .multichain(token: usdt), balance: 2_006_121, consent: user.attempt())
        let logged = try await log.records("Operation review found what would ask in a flow it only logs", count: 2)

        XCTAssertNil(quote.review)
        XCTAssertNil(failure(of: result))
        let asked = await user.asked
        XCTAssertTrue(asked.isEmpty)
        XCTAssertEqual(relayer.sent.count, 1)
        XCTAssertEqual(logged.count, 2, "the quote's and the send's")
    }

    func test_aTokenFeeIsAskedAboutOnSolanaWhereTheReviewReadsTheRelayersTransaction() {
        let token = EVMGaslessFeeOption(payer: .token(usdt, fee: 115_304), relayerAssetId: usdt.assetId)

        XCTAssertEqual(EVMGaslessFeeEngine.presentation(of: token, on: .sol), .ask)
        XCTAssertEqual(EVMGaslessFeeEngine.presentation(of: token, on: .eth), .logOnly)
    }

    /// The operation is read from the sent token's account and held to the amount sent and, for a fee
    /// in a token, to the fee confirmed and the 5% it may rise by, in that token's decimals.
    func test_theOperationIsHeldToTheAmountSentAndATokenFeeToItsBound() async throws {
        let check = WarningCheck()
        checks = [check]
        let log = RecordedLog()
        defer { log.stop() }
        let quote = try await quotedInUSDT(fee: 115_304, balance: 2_006_121)

        _ = await send(quote, picked: .multichain(token: usdt), balance: 2_006_121)
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 2)

        let read = WarningCheck.Read(
            address: GaslessFixtures.sender.lowercased(),
            assetId: GaslessFixtures.usdtId,
            intent: .wallet(
                spending: [OperationIntent.Spend(assetId: GaslessFixtures.usdtId, symbol: "USDT", decimals: 6, amount: 1_000_000)],
                relayerFee: OperationIntent.Spend(assetId: GaslessFixtures.usdtId, symbol: "USDT", decimals: 6, amount: 121_069),
                to: recipient
            )
        )
        let reads = await check.reads.all
        XCTAssertEqual(reads, [read, read], "the quote's and the send's")
    }

    /// ETH sent with the fee paid in USDC: the operation is read from the ETH account, held to the ETH
    /// sent in its 18 decimals and to the USDC fee's bound in USDC's own 6.
    func test_aFeeInAnotherTokenIsHeldToItsBoundInThatTokensDecimals() async throws {
        let check = WarningCheck()
        checks = [check]
        let log = RecordedLog()
        defer { log.stop() }
        let usdc = walletToken(walletUSDCId, balance: 5_000_000)
        walletTokens = [usdc]
        relayer.estimations = [estimation(usdcAsset, fee: 115_304)]
        relayer.emulations[GaslessFixtures.usdcId] = .success(emulation(assetId: GaslessFixtures.usdcId, fee: 115_304))
        let quote = try await quoted(amount: 1_000_000, of: eth, picked: .multichain(token: usdc.asset))

        _ = await send(quote, picked: .multichain(token: usdc.asset), of: eth)
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 2)

        let read = WarningCheck.Read(
            address: GaslessFixtures.sender.lowercased(),
            assetId: eth.assetId,
            intent: .wallet(
                spending: [OperationIntent.Spend(assetId: eth.assetId, symbol: "ETH", decimals: 18, amount: 1_000_000)],
                relayerFee: OperationIntent.Spend(assetId: walletUSDCId, symbol: "USDC", decimals: 6, amount: 121_069),
                to: recipient
            )
        )
        let reads = await check.reads.all
        XCTAssertEqual(reads, [read, read], "the quote's and the send's")
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_chargesAreNotASpendTheOperationIsHeldTo() async throws {
        let check = WarningCheck()
        checks = [check]
        let quote = try await quoted(amount: 1_000_000)

        _ = await send(quote, consent: ConsentingUser(answering: true).attempt())

        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent.spends), [
            [OperationIntent.Spend(assetId: GaslessFixtures.usdtId, symbol: "USDT", decimals: 6, amount: 1_000_000)],
            [OperationIntent.Spend(assetId: GaslessFixtures.usdtId, symbol: "USDT", decimals: 6, amount: 1_000_000)],
        ])
    }

    /// chain-kit reads the relayer's operation paying the 1 USDT to the sender itself rather than to
    /// the recipient: charges are asked about, and nothing is signed before the answer.
    func test_aChargedTransferToSomeoneElseIsRuledOutBeforeAnythingIsAsked() async throws {
        checks = [ChainKitValidationCheck(client: client)]
        relayer.buildsAskedCalls = false

        let quote = try await quoted(amount: 1_000_000)

        XCTAssertNil(quote.emulation)
        XCTAssertNil(quote.review)
        XCTAssertNotEqual(quote.selected(picked: nil)?.relayerAssetId, batteryId)
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    /// Nothing to ask about, and nothing chain-kit failed to read.
    func test_aChargedTransferChainKitFindsNothingInIsSentWithoutAsking() async throws {
        checks = [ChainKitValidationCheck(client: client)]
        let log = RecordedLog()
        defer { log.stop() }
        relayer.emulations[batteryId] = try .success(emulation(
            assetId: batteryId,
            fee: 19,
            calls: [(GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: recipient, amount: 1_000_000)))]
        ))
        let quote = try await quoted(amount: 1_000_000)
        let user = ConsentingUser(answering: false)

        let result = await send(quote, consent: user.attempt())

        XCTAssertNil(failure(of: result))
        XCTAssertEqual(quote.review?.requiresConsent, false)
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(relayer.sent.count, 1)
        XCTAssertEqual(log.errors.map(\.message), [])
    }

    /// The relayer holds its operation to a deadline of its own, which the user can read past.
    func test_anOperationThatExpiredWhileTheUserReadIsNotSigned() async throws {
        checks = [WarningCheck()]
        let quote = try await quoted(amount: 1_000_000)
        let user = ConsentingUser(answering: true) { [clock] in clock.advance(by: 20 * 60) }

        let result = await send(quote, consent: user.attempt())

        guard case .multichainTransactionFailure(.operationExpired)? = failure(of: result) else {
            return XCTFail("expected an expired operation, got \(String(describing: failure(of: result)))")
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_anOperationNoCheckCouldReadIsNotSignedAndIsNoCancellation() async throws {
        checks = [FailingCheck()]
        let quote = try await quoted(amount: 1_000_000)

        let result = await send(quote, consent: ConsentingUser(answering: true).attempt())

        guard case .multichainTransactionFailure(.internal)? = failure(of: result) else {
            return XCTFail("expected an internal failure, got \(String(describing: failure(of: result)))")
        }
        XCTAssertNil(quote.review)
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aFailedReemulationClearsThePreviousSelectionsReview() async throws {
        checks = [WarningCheck()]
        let quote = try await quoted(amount: 1_000_000, nativeInsufficient: true)
        XCTAssertNotNil(quote.review)
        clock.advance(by: 600)
        relayer.emulations.removeAll()

        let refreshed = await engine.quote(quote, picked: .battery, transfer: transfer(amount: 1_000_000))

        XCTAssertNil(refreshed.emulation)
        XCTAssertNil(refreshed.review)
    }

    // MARK: - Helpers

    private var batteryId: String {
        "battery/mainnet"
    }

    private var ethAsset: Components.Schemas.GaslessV2Asset {
        Components.Schemas.GaslessV2Asset(id: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: nil)
    }

    private var usdtAsset: Components.Schemas.GaslessV2Asset {
        Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdtId, name: "USDT", symbol: "USDT", decimals: 6, image: nil)
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

    private func quotedSolanaTransfer() async throws -> (EVMGaslessFeeEngine.Transfer, EVMGaslessFeeEngine.Quote) {
        relayer.buildsAskedCalls = false
        let transfer = transfer(amount: 1_000_000, of: sol, on: .sol, to: solanaSender)
        let estimate = await engine.estimate(transfer)
        let estimated = try XCTUnwrap(estimate)
        let quote = await engine.quote(estimated, picked: nil, transfer: transfer)
        return (transfer, quote)
    }

    private func send(
        _ quote: EVMGaslessFeeEngine.Quote,
        picked: TransactionConfirmationModel.ExtraType? = nil,
        balance: BigUInt = 2_006_121,
        of asset: MultichainAssetDetails? = nil,
        consent: OperationConsent = .refuse
    ) async -> Result<String?, TransactionConfirmationError> {
        let selected = quote.selected(picked: picked)!
        return await engine.send(
            quote,
            selected: selected,
            transfer: transfer(amount: 1_000_000, balance: balance, of: asset),
            passcodeProvider: { "passcode" },
            consent: consent
        )
    }

    /// 1 USDT sent with the fee picked in USDT, quoted at `fee`.
    private func quotedInUSDT(fee: BigUInt, balance: BigUInt) async throws -> EVMGaslessFeeEngine.Quote {
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: fee))
        let quote = try await quoted(amount: 1_000_000, balance: balance, picked: .multichain(token: usdt))
        XCTAssertEqual(quote.selected(picked: .multichain(token: usdt))?.payer, .token(usdt, fee: fee))
        return quote
    }

    private func assertQuoteUnavailable(
        _ result: Result<String?, TransactionConfirmationError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .multichainTransactionFailure(.relayerQuoteUnavailable)? = failure(of: result) else {
            return XCTFail("expected an unavailable quote, got \(String(describing: failure(of: result)))", file: file, line: line)
        }
    }

    private func failure(of result: Result<String?, TransactionConfirmationError>) -> TransactionConfirmationError? {
        guard case let .failure(error) = result else {
            return nil
        }
        return error
    }

    private func transfer(
        amount: BigUInt,
        balance: BigUInt = 2_006_121,
        of asset: MultichainAssetDetails? = nil,
        on chain: MultichainChain = .eth,
        to recipient: String? = nil,
        comment: String? = nil
    ) -> EVMGaslessFeeEngine.Transfer {
        EVMGaslessFeeEngine.Transfer(
            wallet: wallet,
            chain: chain,
            asset: MultichainAsset(
                asset: asset ?? usdt,
                price: .init(prices: [:], diff24h: [:], diff7d: [:]),
                balance: balance
            ),
            amount: amount,
            recipient: recipient ?? self.recipient,
            comment: comment
        )
    }

    private func estimation(battery charges: BigUInt, available: Bool = true) -> EVMGaslessEstimation {
        EVMGaslessEstimation(
            asset: Components.Schemas.GaslessV2Asset(id: batteryId, name: "Battery", symbol: "BATTERY", decimals: 0, image: nil),
            fee: charges,
            isAvailable: available
        )
    }

    private func estimation(_ asset: Components.Schemas.GaslessV2Asset, fee: BigUInt, available: Bool = true) -> EVMGaslessEstimation {
        EVMGaslessEstimation(asset: asset, fee: fee, isAvailable: available)
    }

    /// The relayer's operation making `calls`: by default the transfer of 1 USDT to the sender itself.
    private var askedTransfer: [(target: String, data: String)] {
        [(GaslessFixtures.usdtContract, EVMGaslessCall.erc20TransferData(recipient: recipient, amount: 1_000_000) ?? "")]
    }

    private func emulation(
        assetId: String,
        fee: BigUInt,
        calls: [(target: String, data: String)] = [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)],
        deadline: Date? = nil
    ) -> EVMGaslessEmulation {
        EVMGaslessEmulation(
            assetId: assetId,
            fee: fee,
            operation: try! MultichainRelayedOperation(
                id: "bcef74e1-b940-4142-b7a7-76161850971e",
                json: GaslessFixtures.operation(
                    feeAssetId: assetId,
                    fee: fee.description,
                    calls: calls,
                    deadline: String(Int((deadline ?? clock.now.addingTimeInterval(600)).timeIntervalSince1970))
                )
            ),
            expiresAt: clock.now.addingTimeInterval(10 * 60)
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
                    addresses: [.init(chain: .eth, address: GaslessFixtures.sender), .init(chain: .sol, address: solanaSender)]
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

    var buildsAskedCalls = true
    var now: () -> Date = Date.init

    func emulate(wallet _: Wallet, calls: [EVMGaslessCall], assetId: String) async throws -> EVMGaslessEmulation {
        emulated.append(assetId)
        guard let result = emulations[assetId] else {
            throw EVMGaslessRelayerError.rejected(reason: "no emulation for \(assetId)")
        }
        let emulation = try result.get()
        guard buildsAskedCalls, let call = calls.first else {
            return emulation
        }
        var relayed = calls.map { (target: $0.to, data: $0.data, value: $0.value.description) }
        var mode = "0x0100000000007821000100000000000000000000000000000000000000000000"
        if case let .asset(_, _, _, contract) = AssetIdComponents(assetId: emulation.assetId),
           let transfer = EVMGaslessCall.erc20TransferData(recipient: "0x45a9034c5dc4e1731b7ff8f977e50012822d5b9d", amount: emulation.fee)
        {
            relayed.insert((contract, transfer, "0"), at: 0)
            mode = "0x0101000000007821000100000000000000000000000000000000000000000029"
        }
        return try EVMGaslessEmulation(
            assetId: emulation.assetId,
            fee: emulation.fee,
            operation: MultichainRelayedOperation(
                id: emulation.operation.id,
                json: GaslessFixtures.operation(
                    feeAssetId: emulation.assetId,
                    fee: emulation.fee.description,
                    sender: call.sender,
                    calls: relayed.map { ($0.target, $0.data) },
                    callValues: relayed.map(\.value),
                    mode: mode,
                    deadline: String(Int(now().timeIntervalSince1970) + 10 * 60)
                )
            ),
            expiresAt: emulation.expiresAt
        )
    }

    func emulate(wallet _: Wallet, batch _: EVMBatchRelay, assetId: String) async throws -> EVMGaslessEmulation {
        throw EVMGaslessRelayerError.rejected(reason: "no batch emulation for \(assetId)")
    }

    func send(wallet _: Wallet, signedOperation: Data) async throws -> String? {
        if let sendError {
            throw sendError
        }
        sent.append(signedOperation)
        return nil
    }
}

private final class FakeSigner: MultichainRelayedOperationSigner {
    static let signature = Data("signed".utf8)

    var signed = [MultichainRelayedOperation]()
    var failure: MultichainTransactionFailure?

    func signRelayedOperation(
        passcodeProvider: @escaping () async -> String?,
        wallet _: Wallet,
        chain _: MultichainChain,
        operation: MultichainRelayedOperation
    ) async throws(MultichainTransactionFailure) -> Data {
        if let failure {
            throw failure
        }
        guard await passcodeProvider() != nil else {
            throw .canceled
        }
        signed.append(operation)
        return Self.signature
    }
}
