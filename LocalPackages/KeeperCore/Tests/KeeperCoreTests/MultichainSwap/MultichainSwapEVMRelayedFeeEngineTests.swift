import BigInt
@testable import KeeperCore
import TKBatteryAPI
import TonSwift
import XCTest

/// The fee methods a relayed EVM swap is offered, what paying with one is held to, and what the
/// send answers with. The relayer, the signer and the balances are faked; the route is a USDT sale
/// on Ethereum through a router call.
final class MultichainSwapEVMRelayedFeeEngineTests: XCTestCase {
    private let calls = EngineCalls()
    private lazy var relayer = FakeRelayer(calls: calls)
    private lazy var signer = FakeSigner(calls: calls)
    private var relayedChains: Set<MultichainChain>? = [.eth]
    private var isRelayerEnabled = true
    private var charges = BatteryChargesAvailability.available(100)
    private var paymentCharges: BatteryChargesAvailability?
    private var migrationPending = false
    private lazy var walletTokens = [walletToken(GaslessFixtures.usdcId, balance: 5_000_000)]
    private var tokenLookups = [[String]]()

    /// Looks the wallet's tokens up the way the balance provider does: by what an id names, whatever
    /// its spelling, keyed by the id asked for.
    private lazy var engine = makeEngine(chain: .eth)

    private func makeEngine(chain: MultichainChain) -> MultichainSwapEVMRelayedFeeEngine {
        MultichainSwapEVMRelayedFeeEngine(
            chain: chain,
            relayer: relayer,
            signer: signer,
            relayedChains: { [unowned self] in relayedChains },
            isRelayerEnabled: { [unowned self] _ in isRelayerEnabled },
            batteryCharges: { [unowned self] _ in
                calls.record(.batteryCharges)
                return charges
            },
            walletTokens: { [unowned self] assetIds, _ in
                tokenLookups.append(assetIds)
                return assetIds.reduce(into: [:]) { found, assetId in
                    found[assetId] = walletTokens.first { AssetIdComponents.isSameAsset($0.asset.assetId, assetId) }
                }
            },
            currentBatteryCharges: { [unowned self] _ in
                calls.record(.batteryCharges)
                return paymentCharges ?? charges
            },
            offersBatteryMigration: { [unowned self] _ in migrationPending }
        )
    }

    private let usdt = MultichainAssetDetails(assetId: GaslessFixtures.usdtId, name: "Tether", symbol: "USDT", decimals: 6, image: "")
    /// How the wallet API spells the USDC the relayer names in lowercase.
    private let walletUSDCId = "eth/mainnet/erc20/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    private let batteryId = "battery/mainnet"

    override func setUp() {
        super.setUp()
        relayer.estimations = [
            estimation(battery: 18),
            estimation(usdcAsset, fee: 115_304, available: false),
            estimation(usdtAsset, fee: 115_304),
        ]
        relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 18))
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: 115_304))
    }

    // MARK: - Options

    func test_legacyBatteryCanBeSelectedBeforeMigration() async {
        migrationPending = true
        charges = .unknown
        paymentCharges = .available(0)
        relayer.estimations = [estimation(battery: 18, available: false)]

        let options = await engine.options(context: context())

        XCTAssertEqual(options.first?.method, .battery)
        XCTAssertEqual(options.first?.isInsufficient, false)
        XCTAssertNil(options.first?.availableCharges)
    }

    func test_preparingSwapUsesTheActualBalanceEvenWhenPreviewOffersMigration() async {
        migrationPending = true
        charges = .unknown
        paymentCharges = .available(0)

        do {
            _ = try await engine.prepare(context: context(), confirmed: .batteryCharges(18))
            XCTFail("The preview must not stand in for migrated charges")
        } catch let failure as MultichainSwapExecutionFailure {
            guard case .preparationFailed(kind: .insufficientBalance, reason: _) = failure else {
                return XCTFail("Unexpected failure: \(failure)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_aChainTheRelayerDoesNotServeGetsNoRelayedMethods() async {
        relayedChains = [.arb, .base]

        let options = await engine.options(context: context())

        XCTAssertEqual(options, [])
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    func test_aMethodDroppedAfterPricingAsksForAFreshQuote() async {
        relayedChains = [.arb, .base]

        do {
            _ = try await engine.prepare(context: context(), confirmed: .batteryCharges(18))
            XCTFail("A chain the relayer no longer serves must not be relayed")
        } catch let failure as MultichainSwapExecutionFailure {
            guard case .payloadExpired = failure else {
                return XCTFail("Unexpected failure: \(failure)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    func test_aRelayersAnswerRefusedForWhatItHoldsIsNoNetworkError() async {
        relayer.emulations[batteryId] = .failure(EVMGaslessRelayerError.rejected(reason: "payload p_01 is not a transaction the relayer pays the fee of"))

        do {
            _ = try await engine.prepare(context: context(), confirmed: .batteryCharges(18))
            XCTFail("A refused answer must not be relayed")
        } catch let failure as MultichainSwapExecutionFailure {
            guard case .preparationFailed(kind: .unknown, _) = failure else {
                return XCTFail("Unexpected failure: \(failure)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_nothingIsRelayedWhileTheRelayerConfigIsUnknown() async {
        relayedChains = nil

        let options = await engine.options(context: context())

        XCTAssertEqual(options, [])
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    func test_batteryLeadsThenTheSoldTokenThenAnyOther() async {
        let options = await engine.options(context: context())

        XCTAssertEqual(options.map(\.method), [.battery, .token(assetId: GaslessFixtures.usdtId), .token(assetId: GaslessFixtures.usdcId)])
        XCTAssertEqual(options.map(\.isInsufficient), [false, false, true])
        XCTAssertEqual(options.map(\.relayedFee), [
            .batteryCharges(18),
            .token(assetId: GaslessFixtures.usdtId, amount: 115_304),
            .token(assetId: GaslessFixtures.usdcId, amount: 115_304),
        ])
    }

    /// 1.1 USDT in the wallet and 1 USDT sold: a 0.5 USDT fee has to fit into what is left.
    func test_aFeeInTheSoldTokenIsWeighedAgainstWhatTheSwapLeaves() async {
        relayer.estimations = [estimation(usdtAsset, fee: 500_000)]

        let options = await engine.options(context: context(spent: 1_000_000, balance: 1_100_000))

        XCTAssertEqual(options.map(\.isInsufficient), [true])
        XCTAssertEqual(options.first?.depositAsset, usdt)
    }

    func test_theSoldTokenIsRecognisedUnderTheRelayersSpelling() async {
        let checksummedId = "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7"
        relayer.estimations = [
            estimation(Components.Schemas.GaslessV2Asset(id: checksummedId, name: "Tether USD", symbol: "USDT", decimals: 6, image: nil), fee: 500_000),
        ]
        walletTokens.append(walletToken(checksummedId, symbol: "USDT", balance: 5_000_000))

        let options = await engine.options(context: context(spent: 1_000_000, balance: 1_100_000))

        XCTAssertEqual(options.map(\.method), [.token(assetId: GaslessFixtures.usdtId)])
        XCTAssertEqual(options.map(\.isInsufficient), [true])
    }

    /// A route that did not say what it takes out of the sold token leaves a fee in that token
    /// unverifiable; a fee in any other token is weighed against that token's balance as before.
    func test_aFeeInTheSoldTokenCannotBeVerifiedWhenTheRouteNamesNoSpentAmount() async {
        relayer.estimations = [estimation(usdtAsset, fee: 500_000), estimation(usdcAsset, fee: 500_000)]

        let options = await engine.options(context: context(spent: nil, balance: 5_000_000))

        XCTAssertEqual(options.map(\.method), [.token(assetId: GaslessFixtures.usdtId), .token(assetId: GaslessFixtures.usdcId)])
        XCTAssertEqual(options.map(\.isInsufficient), [true, false])
    }

    /// The tokens the relayer takes are read in one go; the sold token and the ones it rules out
    /// are not read at all.
    func test_theTokensTheRelayerTakesAreLookedUpOnce() async {
        let dai = Components.Schemas.GaslessV2Asset(
            id: "eth/mainnet/erc20/0x6b175474e89094c44da98b954eedeac495271d0f", name: "Dai", symbol: "DAI", decimals: 18, image: nil
        )
        relayer.estimations = [
            estimation(battery: 18),
            estimation(usdcAsset, fee: 115_304),
            estimation(dai, fee: 115_304, available: false),
            estimation(usdtAsset, fee: 115_304),
        ]

        _ = await engine.options(context: context())

        XCTAssertEqual(tokenLookups, [[GaslessFixtures.usdcId]])
    }

    /// The relayer spells USDC in lowercase where the wallet checksums it: the method, what it is
    /// weighed against and where its deposit leads all go by the wallet's entry.
    func test_anotherTokenIsNamedByTheWalletsIdForIt() async {
        let usdc = walletToken(walletUSDCId, balance: 100_000)
        walletTokens = [usdc]
        relayer.estimations = [estimation(usdcAsset, fee: 115_304)]

        let options = await engine.options(context: context())

        XCTAssertEqual(options.map(\.method), [.token(assetId: walletUSDCId)])
        XCTAssertEqual(options.map(\.isInsufficient), [true])
        XCTAssertEqual(options.first?.depositAsset, usdc.asset)
    }

    func test_anotherTokenWhoseBalanceCannotBeReadCannotPay() async {
        walletTokens = []
        relayer.estimations = [estimation(usdcAsset, fee: 115_304)]

        let options = await engine.options(context: context())

        XCTAssertEqual(options.map(\.method), [.token(assetId: GaslessFixtures.usdcId)])
        XCTAssertEqual(options.map(\.isInsufficient), [true])
    }

    func test_batteryWithoutTheChargesIsStillListedForARefill() async {
        charges = .available(3)

        let options = await engine.options(context: context())

        XCTAssertEqual(options.first?.method, .battery)
        XCTAssertEqual(options.first?.isInsufficient, true)
        XCTAssertNil(options.first?.depositAsset)
    }

    func test_aSwapBehindAnApproveKeepsThePlainFee() async {
        let options = await engine.options(context: context(requiresApproval: true))

        XCTAssertTrue(options.isEmpty)
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    func test_aRelayerSwitchedOffOffersNothing() async {
        isRelayerEnabled = false

        let options = await engine.options(context: context())

        XCTAssertTrue(options.isEmpty)
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    func test_anotherChainsPayloadIsNotThisEnginesToPrice() async {
        let options = await engine.options(context: context(chain: .base))

        XCTAssertTrue(options.isEmpty)
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    /// A Solana route, deposit or transaction, is the Solana engine's to price, with the same methods.
    func test_aSolanaRouteIsPricedByTheSolanaEngineOnly() async {
        relayedChains = [.eth, .sol]
        let route = MultichainSwapBatteryPayload.solana(
            EVMSwapRelay(chain: .sol, call: .solanaSwap(sender: "9wFFyRfZBsuAha4YcuxcXLKwMxJR43S7fPfQLusDBzvT", transaction: "AQ=="))
        )

        let solanaOptions = await makeEngine(chain: .sol).options(context: context(payload: route))
        let evmOptions = await engine.options(context: context(payload: route))

        XCTAssertEqual(solanaOptions.map(\.method), [.battery, .token(assetId: GaslessFixtures.usdtId), .token(assetId: GaslessFixtures.usdcId)])
        XCTAssertTrue(evmOptions.isEmpty)
        XCTAssertEqual(relayer.estimateCalls, 1)
    }

    func test_aLegacyWalletHasNoEVMKeyToSignWith() async {
        let options = await engine.options(context: context(keys: .legacy))

        XCTAssertTrue(options.isEmpty)
    }

    func test_anEstimateThatFailsKeepsThePlainFee() async {
        relayer.estimateError = URLError(.badServerResponse)

        let options = await engine.options(context: context())

        XCTAssertTrue(options.isEmpty)
    }

    // MARK: - Send

    func test_aBatterySwapIsEmulatedSignedAndHandedToTheRelayer() async throws {
        let hash = try await send(context: context(), confirmed: .batteryCharges(18), signer: .mnemonic(passcodeProvider: { "passcode" }))

        XCTAssertNil(hash)
        XCTAssertEqual(relayer.emulated, [batteryId])
        XCTAssertEqual(signer.signed.map(\.id), ["bcef74e1-b940-4142-b7a7-76161850971e"])
        XCTAssertEqual(relayer.sent, [FakeSigner.signature])
    }

    /// The confirmed price is held against the relayer's fresh emulation before anything is signed,
    /// and the passcode is left to the signer, which asks it once signing starts.
    func test_aSwapIsEmulatedPricedSignedAndOnlyThenRelayed() async throws {
        let prepared = try await engine.prepare(context: context(), confirmed: .batteryCharges(18))

        XCTAssertEqual(calls.recorded, [.estimate, .emulate, .batteryCharges])

        _ = try await prepared.send(.mnemonic(passcodeProvider: { [calls] in
            calls.record(.passcode)
            return "passcode"
        }))

        XCTAssertEqual(calls.recorded, [.estimate, .emulate, .batteryCharges, .passcode, .sign, .relay])
    }

    /// What the review reads is the relayer's operation itself, in the account of the token sold.
    func test_whatIsSignedIsTheOperationThePreparedSwapDescribes() async throws {
        let prepared = try await engine.prepare(context: context(), confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 115_304))
        let signables = try await prepared.signables(.wallet(
            spending: [OperationIntent.Spend(assetId: GaslessFixtures.usdtId, symbol: "USDT", decimals: 6, amount: 1_000_000)],
            to: nil
        ))

        _ = try await prepared.send(.mnemonic(passcodeProvider: { "passcode" }))

        XCTAssertEqual(signables.map(\.operation.id), signer.signed.map(\.operation.id))
        XCTAssertEqual(signables.map(\.operation.meta), signer.signed.map(\.operation.meta))
        XCTAssertEqual(signables.map(\.fidelity), [.exact])
        XCTAssertEqual(signables.first?.account.asset.id, GaslessFixtures.usdtId)
        XCTAssertEqual(signables.first?.account.addressDisplay.lowercased(), GaslessFixtures.sender.lowercased())
        XCTAssertEqual(prepared.expiresAt, try relayer.emulations[GaslessFixtures.usdtId]?.get().expiresAt)
    }

    func test_aSentSwapReturnsTheHashTheRelayerNames() async throws {
        relayer.sentHash = "0xabc"

        let hash = try await send(context: context(), confirmed: .batteryCharges(18), signer: .mnemonic(passcodeProvider: { "passcode" }))

        XCTAssertEqual(hash, "0xabc")
    }

    func test_aTokenSwapIsEmulatedUnderTheRelayersAssetId() async throws {
        _ = try await send(
            context: context(),
            confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 115_304),
            signer: .mnemonic(passcodeProvider: { "passcode" })
        )

        XCTAssertEqual(relayer.emulated, [GaslessFixtures.usdtId])
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_aTokenConfirmedUnderTheWalletsIdIsEmulatedUnderTheRelayers() async throws {
        walletTokens = [walletToken(walletUSDCId, balance: 5_000_000)]
        relayer.estimations = [estimation(usdcAsset, fee: 115_304)]
        relayer.emulations[GaslessFixtures.usdcId] = .success(emulation(assetId: GaslessFixtures.usdcId, fee: 115_304))

        _ = try await send(
            context: context(),
            confirmed: .token(assetId: walletUSDCId, amount: 115_304),
            signer: .mnemonic(passcodeProvider: { "passcode" })
        )

        XCTAssertEqual(relayer.emulated, [GaslessFixtures.usdcId])
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_aBatteryRequoteAboveTheConfirmedPriceIsRefused() async {
        relayer.emulations[batteryId] = .success(emulation(assetId: batteryId, fee: 19))

        await assertSendFails(confirmed: .batteryCharges(18)) { failure in
            guard case .preparationFailed(kind: .unknown, _) = failure else {
                return XCTFail("expected a refused re-quote, got \(failure)")
            }
        }
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aTokenRequoteWithinTheToleranceIsSent() async throws {
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: 120_000))

        _ = try await send(
            context: context(),
            confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 115_304),
            signer: .mnemonic(passcodeProvider: { "passcode" })
        )

        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_aTokenRequotePastTheToleranceIsRefused() async {
        relayer.emulations[GaslessFixtures.usdtId] = .success(emulation(assetId: GaslessFixtures.usdtId, fee: 123_433))

        await assertSendFails(confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 115_304)) { failure in
            guard case .preparationFailed(kind: .unknown, _) = failure else {
                return XCTFail("expected a refused re-quote, got \(failure)")
            }
        }
    }

    func test_aFeeInTheSoldTokenIsNotSentWhenTheRouteNamesNoSpentAmount() async {
        await assertSendFails(
            context: context(spent: nil, balance: 5_000_000),
            confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 115_304)
        ) { failure in
            guard case .preparationFailed(kind: .insufficientBalance, _) = failure else {
                return XCTFail("expected an insufficient balance, got \(failure)")
            }
        }
        XCTAssertTrue(signer.signed.isEmpty)
    }

    func test_aFeeTheBalanceNoLongerCoversIsNotSent() async {
        charges = .available(5)

        await assertSendFails(confirmed: .batteryCharges(18)) { failure in
            guard case .preparationFailed(kind: .insufficientBalance, _) = failure else {
                return XCTFail("expected an insufficient balance, got \(failure)")
            }
        }
        XCTAssertTrue(signer.signed.isEmpty)
    }

    func test_aDismissedPasscodePromptCancelsTheSend() async {
        signer.failure = .canceled

        await assertSendFails(confirmed: .batteryCharges(18)) { failure in
            guard case .canceled = failure else {
                return XCTFail("expected a cancellation, got \(failure)")
            }
        }
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    /// Nothing was broadcast, so the slider may be re-armed after a fresh quote.
    func test_aRelayerThatForgotTheOperationFailsBeforeBroadcasting() async {
        relayer.sendError = EVMGaslessRelayerError.quoteExpired

        await assertSendFails(confirmed: .batteryCharges(18)) { failure in
            guard case .preparationFailed(kind: .networkError, _) = failure else {
                return XCTFail("expected a re-armable failure, got \(failure)")
            }
            XCTAssertFalse(Self.isOutcomeUnknown(failure))
        }
    }

    /// A relayer that did not answer may be holding the operation: the swap must not be re-armed.
    func test_aRelayerThatDidNotAnswerLeavesTheOutcomeUnknown() async {
        relayer.sendError = URLError(.timedOut)

        await assertSendFails(confirmed: .batteryCharges(18)) { failure in
            XCTAssertTrue(Self.isOutcomeUnknown(failure), "\(failure)")
        }
    }

    /// Each attempt builds another transaction: a refusal that may follow a broadcast must not re-arm the swap.
    func test_aRefusalThatMayFollowABroadcastLeavesTheOutcomeUnknown() async {
        relayer.sendError = EVMGaslessRelayerError.rejected(reason: "broadcast_failed: rpc timeout", mayHaveBroadcast: true)

        await assertSendFails(confirmed: .batteryCharges(18)) { failure in
            XCTAssertTrue(Self.isOutcomeUnknown(failure), "\(failure)")
        }
    }

    func test_aRefusalBeforeTheBroadcastCanBeRetried() async {
        relayer.sendError = EVMGaslessRelayerError.rejected(reason: "insufficient_funds: no charges", mayHaveBroadcast: false)

        await assertSendFails(confirmed: .batteryCharges(18)) { failure in
            guard case .preparationFailed(kind: .unknown, _) = failure else {
                return XCTFail("expected a refusal before the broadcast, got \(failure)")
            }
        }
    }

    func test_gramCannotPayForAnEVMSwap() async {
        await assertSendFails(confirmed: .gram(amountNano: 1)) { failure in
            guard case .internal = failure else {
                return XCTFail("expected an internal failure, got \(failure)")
            }
        }
        XCTAssertTrue(relayer.emulated.isEmpty)
    }

    func test_aSwapIsNotSignedForOtherCallsAnotherModeOrAnotherDelegate() async {
        let refused = [
            emulation(assetId: batteryId, fee: 18, calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)]),
            emulation(assetId: batteryId, fee: 18, calls: [swapCall, (GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)]),
            emulation(assetId: batteryId, fee: 18, mode: tokenFeeMode),
            emulation(
                assetId: batteryId,
                fee: 18,
                authorizationMeta: #"{ "address": "0x00000000000000000000000000000000000000aa", "nonce": 41, "chainId": 1 }"#
            ),
        ]
        for emulation in refused {
            relayer.emulations[batteryId] = .success(emulation)
            await assertSendFails(confirmed: .batteryCharges(18)) { failure in
                guard case .preparationFailed(kind: .unknown, _) = failure else {
                    return XCTFail("expected a refused operation, got \(failure)")
                }
            }
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aTokenSwapIsNotSignedForAnotherFeeTransfer() async throws {
        let fee: BigUInt = 115_304
        let refused = try [
            emulation(assetId: GaslessFixtures.usdtId, fee: fee, calls: [feeTransfer(GaslessFixtures.usdtId, fee + 1), swapCall]),
            emulation(assetId: GaslessFixtures.usdtId, fee: fee, calls: [feeTransfer(GaslessFixtures.usdcId, fee), swapCall]),
            emulation(assetId: GaslessFixtures.usdtId, fee: fee, calls: [swapCall, feeTransfer(GaslessFixtures.usdtId, fee)]),
            emulation(assetId: GaslessFixtures.usdtId, fee: fee, calls: [swapCall]),
            emulation(assetId: GaslessFixtures.usdtId, fee: fee, mode: signedBatchMode),
            emulation(
                assetId: GaslessFixtures.usdtId,
                fee: fee,
                calls: [(GaslessFixtures.usdtContract, "0x095ea7b3" + String(XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: feeRecipient, amount: fee)?.dropFirst(10)))), swapCall]
            ),
        ]
        for emulation in refused {
            relayer.emulations[GaslessFixtures.usdtId] = .success(emulation)
            await assertSendFails(confirmed: .token(assetId: GaslessFixtures.usdtId, amount: fee)) { failure in
                guard case .preparationFailed(kind: .unknown, _) = failure else {
                    return XCTFail("expected a refused operation, got \(failure)")
                }
            }
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aTokenSwapIsSignedWithAFeeTransferBelowTheQuote() async throws {
        relayer.emulations[GaslessFixtures.usdtId] = .success(
            emulation(assetId: GaslessFixtures.usdtId, fee: 115_304, calls: [feeTransfer(GaslessFixtures.usdtId, 100_000), swapCall])
        )

        _ = try await send(
            context: context(),
            confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 115_304),
            signer: .mnemonic(passcodeProvider: { "passcode" })
        )

        XCTAssertEqual(signer.signed.count, 1)
    }

    func test_aSwapForAnAlreadyDelegatedAddressSignsTheExecuteAlone() async throws {
        relayer.emulations[batteryId] = try .success(textualEmulation(fee: 18, calls: [swapCall], repeatingMessage: false, delegated: true))

        _ = try await send(context: context(), confirmed: .batteryCharges(18), signer: .mnemonic(passcodeProvider: { "passcode" }))

        XCTAssertEqual(signer.signed.count, 1)
    }

    func test_aSwapWhoseExecuteRepeatsAKeyIsNotSigned() async throws {
        relayer.emulations[batteryId] = try .success(textualEmulation(fee: 18, calls: [swapCall], repeatingMessage: true))

        await assertSendFails(confirmed: .batteryCharges(18)) { failure in
            guard case .preparationFailed(kind: .unknown, _) = failure else {
                return XCTFail("expected a refused operation, got \(failure)")
            }
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aSwapIsNotSignedUnderAnotherDomainDeadlineOrAuthorizationChain() async {
        let now = Int(Date().timeIntervalSince1970)
        let refused = [
            emulation(assetId: batteryId, fee: 18, chainId: 56),
            emulation(assetId: batteryId, fee: 18, owner: "0x00000000000000000000000000000000000000aa"),
            emulation(assetId: batteryId, fee: 18, deadline: String(now + 2 * 24 * 60 * 60)),
            emulation(assetId: batteryId, fee: 18, deadline: String(now - 60)),
            emulation(
                assetId: batteryId,
                fee: 18,
                authorizationMeta: #"{ "address": "0x24b576BC271823bF9C24BE627B4363b9b00191e9", "nonce": 41, "chainId": 0 }"#
            ),
        ]
        for emulation in refused {
            relayer.emulations[batteryId] = .success(emulation)
            await assertSendFails(confirmed: .batteryCharges(18)) { failure in
                guard case .preparationFailed(kind: .unknown, _) = failure else {
                    return XCTFail("expected a refused operation, got \(failure)")
                }
            }
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aSolanaSwapIsAskedAboutWhateverPaysItsFee() {
        let relay = EVMSwapRelay(chain: .sol, call: .solanaSwap(sender: String(repeating: "1", count: 32), transaction: "AA=="))
        func send(_ fee: MultichainSwapRelayedFee) -> MultichainSwapRelayedSend {
            MultichainSwapRelayedSend(payload: .solana(relay), confirmed: fee, tokenFee: nil, recipient: nil)
        }

        XCTAssertEqual(send(.batteryCharges(1)).presentation, .ask)
        XCTAssertEqual(send(.token(assetId: "sol/mainnet/spl/Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB", amount: 925)).presentation, .ask)
    }

    func test_aRelayerChainWithoutTheHermesDelegateGetsNoRelayedMethods() async {
        let avaxEngine = MultichainSwapEVMRelayedFeeEngine(
            chain: .avax,
            relayer: relayer,
            signer: signer,
            relayedChains: { [.avax] },
            isRelayerEnabled: { _ in true },
            batteryCharges: { _ in .available(100) },
            walletTokens: { _, _ in [:] }
        )

        let options = await avaxEngine.options(context: context(chain: .avax))

        XCTAssertEqual(options, [])
        XCTAssertEqual(relayer.estimateCalls, 0)
    }

    // MARK: - Batch

    func test_aBatchIsPricedInBatteryChargesByEmulatingItWhole() async {
        relayer.emulations[batteryId] = .success(batchEmulation(fee: 2))

        let options = await engine.options(context: context(payload: .evmBatch(batch)))

        XCTAssertEqual(options, [
            MultichainSwapFeeOption(
                cost: .batteryCharges(count: 2, excess: nil, isInsufficient: false),
                availableCharges: 100
            ),
        ])
        XCTAssertEqual(relayer.estimateCalls, 0)
        XCTAssertEqual(relayer.emulatedBatches, [batch])
    }

    func test_aBatchTheRelayerBuiltOtherwiseIsNotOfferedForCharges() async throws {
        let foreign = "0x000000000000000000000000000000000000dead"
        relayer.emulations[batteryId] = try .success(EVMGaslessEmulation(
            assetId: batteryId,
            fee: 2,
            operation: MultichainRelayedOperation(
                id: "bcef74e1-b940-4142-b7a7-76161850971e",
                json: GaslessFixtures.operation(fee: "2", calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer), (foreign, swapData)], mode: signedBatchMode, deadline: freshDeadline)
            ),
            expiresAt: Date().addingTimeInterval(10 * 60)
        ))

        let options = await engine.options(context: context(payload: .evmBatch(batch)))

        XCTAssertEqual(options, [])
    }

    func test_aBatchWhoseDeadlineTheDeviceClockHasPassedIsStillOfferedForCharges() async throws {
        let relayersNow = Date().addingTimeInterval(-20 * 60)
        relayer.emulations[batteryId] = try .success(EVMGaslessEmulation(
            assetId: batteryId,
            fee: 2,
            operation: MultichainRelayedOperation(
                id: "bcef74e1-b940-4142-b7a7-76161850971e",
                json: GaslessFixtures.operation(
                    fee: "2",
                    calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer), (router, swapData)],
                    mode: signedBatchMode,
                    deadline: String(Int(relayersNow.timeIntervalSince1970) + 10 * 60)
                )
            ),
            expiresAt: relayersNow.addingTimeInterval(10 * 60)
        ))

        let options = await engine.options(context: context(payload: .evmBatch(batch)))

        XCTAssertEqual(options.count, 1)
    }

    func test_aBatchIsEmulatedSignedAndHandedToTheRelayer() async throws {
        relayer.emulations[batteryId] = .success(batchEmulation(fee: 2))

        let hash = try await send(context: context(payload: .evmBatch(batch)), confirmed: .batteryCharges(2), signer: .mnemonic(passcodeProvider: { "passcode" }))

        XCTAssertNil(hash)
        XCTAssertEqual(relayer.emulatedBatches, [batch])
        XCTAssertEqual(signer.signed.count, 1)
        XCTAssertEqual(relayer.sent, [FakeSigner.signature])
    }

    func test_aBatchIsNotSignedWhenTheRelayersExecuteRunsOtherCalls() async throws {
        let foreign = "0x000000000000000000000000000000000000dead"
        let operations: [(String, String)] = [
            ("a call swapped for another", GaslessFixtures.operation(fee: "2", calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer), (foreign, swapData)], mode: signedBatchMode, deadline: freshDeadline)),
            ("a call dropped", GaslessFixtures.operation(fee: "2", calls: [(router, swapData)], mode: signedBatchMode, deadline: freshDeadline)),
            ("a call added", GaslessFixtures.operation(fee: "2", calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer), (router, swapData), (foreign, "0x")], mode: signedBatchMode, deadline: freshDeadline)),
            ("an Execute the account runs itself", GaslessFixtures.operation(fee: "2", calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer), (router, swapData)], mode: "0x01" + String(repeating: "0", count: 62), deadline: freshDeadline)),
        ]
        for (name, json) in operations {
            relayer.emulations[batteryId] = try .success(EVMGaslessEmulation(
                assetId: batteryId,
                fee: 2,
                operation: MultichainRelayedOperation(id: "bcef74e1-b940-4142-b7a7-76161850971e", json: json),
                expiresAt: Date().addingTimeInterval(10 * 60)
            ))

            await assertSendFails(context: context(payload: .evmBatch(batch)), confirmed: .batteryCharges(2)) { failure in
                guard case .preparationFailed = failure else {
                    return XCTFail("\(name): expected the preparation to fail, got \(failure)")
                }
            }
        }
        XCTAssertTrue(signer.signed.isEmpty)
        XCTAssertTrue(relayer.sent.isEmpty)
    }

    func test_aBatchIsNeverRelayedAgainstAToken() async {
        await assertSendFails(context: context(payload: .evmBatch(batch)), confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 1)) { failure in
            guard case .internal = failure else {
                return XCTFail("expected an internal failure, got \(failure)")
            }
        }
        XCTAssertTrue(relayer.emulated.isEmpty)
    }

    // MARK: - Helpers

    /// Prepares and sends in one go, as a swap does when nothing reviews it in between.
    private func send(
        context: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee,
        signer: MultichainTransferSigner
    ) async throws(MultichainSwapExecutionFailure) -> String? {
        try await engine.prepare(context: context, confirmed: confirmed).send(signer)
    }

    private func assertSendFails(
        context: MultichainSwapFeeContext? = nil,
        confirmed: MultichainSwapRelayedFee,
        _ check: (MultichainSwapExecutionFailure) -> Void
    ) async {
        do {
            _ = try await send(context: context ?? self.context(), confirmed: confirmed, signer: .mnemonic(passcodeProvider: { "passcode" }))
            XCTFail("expected the send to fail")
        } catch {
            check(error)
        }
    }

    private static func isOutcomeUnknown(_ failure: MultichainSwapExecutionFailure) -> Bool {
        guard case .broadcastFailed = failure else {
            return false
        }
        return true
    }

    private var usdtAsset: Components.Schemas.GaslessV2Asset {
        Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdtId, name: "USDT", symbol: "USDT", decimals: 6, image: nil)
    }

    private var usdcAsset: Components.Schemas.GaslessV2Asset {
        Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdcId, name: "USDC", symbol: "USDC", decimals: 6, image: nil)
    }

    private func walletToken(_ assetId: String, symbol: String = "USDC", balance: BigUInt) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(assetId: assetId, name: symbol, symbol: symbol, decimals: 6, image: ""),
            price: .init(prices: [:], diff24h: [:], diff7d: [:]),
            balance: balance
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

    private func emulation(
        assetId: String,
        fee: BigUInt,
        calls: [(target: String, data: String)]? = nil,
        mode: String? = nil,
        authorizationMeta: String = GaslessFixtures.authorizationMeta,
        owner: String = GaslessFixtures.sender,
        chainId: Int = 1,
        deadline: String? = nil
    ) -> EVMGaslessEmulation {
        let isBattery = assetId == batteryId
        return EVMGaslessEmulation(
            assetId: assetId,
            fee: fee,
            operation: try! MultichainRelayedOperation(
                id: "bcef74e1-b940-4142-b7a7-76161850971e",
                json: GaslessFixtures.operation(
                    feeAssetId: assetId,
                    fee: fee.description,
                    sender: owner,
                    authorizationMeta: authorizationMeta,
                    calls: calls ?? (isBattery ? [swapCall] : [feeTransfer(assetId, fee), swapCall]),
                    mode: mode ?? (isBattery ? signedBatchMode : tokenFeeMode),
                    chainId: chainId,
                    deadline: deadline ?? freshDeadline
                )
            ),
            expiresAt: Date().addingTimeInterval(10 * 60)
        )
    }

    private func feeTransfer(_ assetId: String, _ amount: BigUInt) -> (target: String, data: String) {
        (String(assetId.split(separator: "/").last!), EVMGaslessCall.erc20TransferData(recipient: feeRecipient, amount: amount)!)
    }

    private let router = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
    private var freshDeadline: String {
        String(Int(Date().timeIntervalSince1970) + 10 * 60)
    }

    private let swapData = "0x38ed1739"
    private var swapCall: (target: String, data: String) {
        (router, swapData)
    }

    private let feeRecipient = "0x45a9034c5dc4e1731b7ff8f977e50012822d5b9d"
    private let tokenFeeMode = "0x0101000000007821000100000000000000000000000000000000000000000009"
    private let signedBatchMode = "0x0100000000007821000100000000000000000000000000000000000000000000"

    /// A Hermes batch as the quote has it: the address calls itself to run an approval and the router call.
    private var batch: EVMBatchRelay {
        EVMBatchRelay(
            chain: .eth,
            sender: GaslessFixtures.sender,
            payload: try! JSONDecoder().decode(Components.Schemas.GaslessV2Payload.self, from: Data("""
            { "id": "p_batch", "type": "main", "chain_id": "eth/mainnet", "version": 1,
              "meta": { "to": "\(GaslessFixtures.sender)", "value": "0", "data": "0xe9ae5c53" } }
            """.utf8)),
            calls: [
                HermesExecute.Call(target: GaslessFixtures.usdtContract, value: "0", data: GaslessFixtures.usdtTransfer),
                HermesExecute.Call(target: router, value: "0", data: swapData),
            ]
        )
    }

    private func batchEmulation(fee: BigUInt) -> EVMGaslessEmulation {
        EVMGaslessEmulation(
            assetId: batteryId,
            fee: fee,
            operation: try! MultichainRelayedOperation(
                id: "bcef74e1-b940-4142-b7a7-76161850971e",
                json: GaslessFixtures.operation(
                    fee: fee.description,
                    calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer), (router, "0x38ed1739")],
                    mode: signedBatchMode,
                    deadline: freshDeadline
                )
            ),
            expiresAt: Date().addingTimeInterval(10 * 60)
        )
    }

    private func textualEmulation(
        fee: BigUInt,
        calls: [(target: String, data: String)],
        repeatingMessage: Bool,
        delegated: Bool = false
    ) throws -> EVMGaslessEmulation {
        let json = GaslessFixtures.operation(fee: fee.description, calls: calls, mode: signedBatchMode, deadline: freshDeadline)
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        var payloads = try XCTUnwrap(envelope["payloads"] as? [[String: Any]])
        var meta = try XCTUnwrap(payloads[1]["meta"] as? [String: Any])
        let document = try XCTUnwrap(meta["data"] as? [String: Any])
        var text = try String(decoding: JSONSerialization.data(withJSONObject: document, options: .sortedKeys), as: UTF8.self)
        if repeatingMessage {
            var message = try XCTUnwrap(document["message"] as? [String: Any])
            message["calls"] = [["target": "0x00000000000000000000000000000000000000aa", "value": "0", "data": "0x"]]
            let other = try String(decoding: JSONSerialization.data(withJSONObject: message, options: .sortedKeys), as: UTF8.self)
            text = String(text.dropLast()) + #","message":"# + other + "}"
        }
        meta["data"] = text
        payloads[1]["meta"] = meta
        envelope["payloads"] = delegated ? [payloads[1]] : payloads
        return try EVMGaslessEmulation(
            assetId: batteryId,
            fee: fee,
            operation: MultichainRelayedOperation(
                id: "bcef74e1-b940-4142-b7a7-76161850971e",
                json: String(decoding: JSONSerialization.data(withJSONObject: envelope), as: UTF8.self)
            ),
            expiresAt: Date().addingTimeInterval(10 * 60)
        )
    }

    private func context(
        chain: MultichainChain = .eth,
        spent: BigUInt? = 1_000_000,
        balance: BigUInt = 2_006_121,
        requiresApproval: Bool = false,
        keys: MultichainSwapWallet.Keys = .hd,
        payload: MultichainSwapBatteryPayload? = nil
    ) -> MultichainSwapFeeContext {
        let call = EVMGaslessCall.swap(
            chain: chain,
            sender: GaslessFixtures.sender,
            assetId: GaslessFixtures.usdtId,
            to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
            amount: 0,
            data: "0x38ed1739"
        )!
        return MultichainSwapFeeContext(
            swapWallet: swapWallet(keys: keys),
            sourceAsset: MultichainAsset(
                asset: usdt,
                price: .init(prices: [:], diff24h: [:], diff7d: [:]),
                balance: balance
            ),
            payloadId: "main",
            requiresApproval: requiresApproval,
            payload: payload ?? .evm(EVMSwapRelay(chain: chain, call: call)),
            spentSourceAmount: spent
        )
    }

    private func swapWallet(keys: MultichainSwapWallet.Keys) -> MultichainSwapWallet {
        let state = MultichainWalletState(
            walletId: "multichain-wallet-id",
            addresses: [
                .init(chain: .eth, address: GaslessFixtures.sender),
                .init(chain: .base, address: GaslessFixtures.sender),
                .init(chain: .avax, address: GaslessFixtures.sender),
                .init(chain: .sol, address: "9wFFyRfZBsuAha4YcuxcXLKwMxJR43S7fPfQLusDBzvT"),
            ]
        )
        let wallet = Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: .init(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(state)
        )
        return MultichainSwapWallet(
            wallet: wallet,
            addresses: state.addresses,
            registration: .registered(walletId: state.walletId),
            keys: keys
        )
    }
}

/// What the engine asks of the relayer, the balances and the signer, in the order it asks.
private final class EngineCalls {
    enum Call: Equatable {
        case estimate
        case emulate
        case batteryCharges
        case passcode
        case sign
        case relay
    }

    private(set) var recorded = [Call]()

    func record(_ call: Call) {
        recorded.append(call)
    }
}

private final class FakeRelayer: EVMGaslessRelaying {
    var estimations = [EVMGaslessEstimation]()
    var estimateError: Error?
    var estimateCalls = 0
    var emulations = [String: Result<EVMGaslessEmulation, Error>]()
    var emulated = [String]()
    var emulatedBatches = [EVMBatchRelay]()
    var sent = [Data]()
    var sentHash: String?
    var sendError: Error?
    private let calls: EngineCalls

    init(calls: EngineCalls) {
        self.calls = calls
    }

    func estimate(wallet _: Wallet, call _: EVMGaslessCall) async throws -> [EVMGaslessEstimation] {
        calls.record(.estimate)
        estimateCalls += 1
        if let estimateError {
            throw estimateError
        }
        return estimations
    }

    func emulate(wallet _: Wallet, calls _: [EVMGaslessCall], assetId: String) async throws -> EVMGaslessEmulation {
        try emulation(assetId)
    }

    func emulate(wallet _: Wallet, batch: EVMBatchRelay, assetId: String) async throws -> EVMGaslessEmulation {
        emulatedBatches.append(batch)
        return try emulation(assetId)
    }

    private func emulation(_ assetId: String) throws -> EVMGaslessEmulation {
        calls.record(.emulate)
        emulated.append(assetId)
        guard let result = emulations[assetId] else {
            throw EVMGaslessRelayerError.rejected(reason: "no emulation for \(assetId)")
        }
        return try result.get()
    }

    func send(wallet _: Wallet, signedOperation: Data) async throws -> String? {
        calls.record(.relay)
        if let sendError {
            throw sendError
        }
        sent.append(signedOperation)
        return sentHash
    }
}

/// Unlocks the way the real signer does: the passcode is asked as signing starts, and a declined
/// one cancels.
private final class FakeSigner: MultichainRelayedOperationSigner {
    static let signature = Data("signed".utf8)

    var signed = [MultichainRelayedOperation]()
    var failure: MultichainTransactionFailure?
    private let calls: EngineCalls

    init(calls: EngineCalls) {
        self.calls = calls
    }

    func signRelayedOperation(
        passcodeProvider: @escaping () async -> String?,
        wallet _: Wallet,
        chain _: MultichainChain,
        operation: MultichainRelayedOperation
    ) async throws(MultichainTransactionFailure) -> Data {
        guard await passcodeProvider() != nil else {
            throw .canceled
        }
        calls.record(.sign)
        if let failure {
            throw failure
        }
        signed.append(operation)
        return Self.signature
    }
}
