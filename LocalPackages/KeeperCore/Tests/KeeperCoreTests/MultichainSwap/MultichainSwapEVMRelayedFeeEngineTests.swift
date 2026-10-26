import BigInt
@testable import KeeperCore
import TKBatteryAPI
import TonSwift
import XCTest

/// The fee methods a relayed EVM swap is offered, what paying with one is held to, and what the
/// send answers with. The relayer, the signer and the balances are faked; the route is a USDT sale
/// on Ethereum through a router call.
final class MultichainSwapEVMRelayedFeeEngineTests: XCTestCase {
    private let relayer = FakeRelayer()
    private let signer = FakeSigner()
    private var relayedChains: Set<MultichainChain>? = [.eth]
    private var isRelayerEnabled = true
    private var charges = BatteryChargesAvailability.available(100)
    private lazy var walletTokens = [walletToken(GaslessFixtures.usdcId, balance: 5_000_000)]
    private var tokenLookups = [[String]]()

    /// Looks the wallet's tokens up the way the balance provider does: by what an id names, whatever
    /// its spelling, keyed by the id asked for.
    private lazy var engine = MultichainSwapEVMRelayedFeeEngine(
        chain: .eth,
        relayer: relayer,
        signer: signer,
        relayedChains: { [unowned self] in relayedChains },
        isRelayerEnabled: { [unowned self] _ in isRelayerEnabled },
        batteryCharges: { [unowned self] _ in charges },
        walletTokens: { [unowned self] assetIds, _ in
            tokenLookups.append(assetIds)
            return assetIds.reduce(into: [:]) { found, assetId in
                found[assetId] = walletTokens.first { AssetIdComponents.isSameAsset($0.asset.assetId, assetId) }
            }
        }
    )

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

    func test_aChainTheRelayerDoesNotServeGetsNoRelayedMethods() async {
        relayedChains = [.arb, .base]

        let options = await engine.options(context: context())

        XCTAssertEqual(options, [])
        XCTAssertEqual(relayer.estimateCalls, 0)
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
            estimation(Components.Schemas.GaslessV2Asset(id: checksummedId, name: "Tether USD", symbol: "USDT", decimals: 6, image: nil, chain: "eth"), fee: 500_000),
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
            id: "eth/mainnet/erc20/0x6b175474e89094c44da98b954eedeac495271d0f", name: "Dai", symbol: "DAI", decimals: 18, image: nil, chain: "eth"
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
        let hash = try await engine.send(context: context(), confirmed: .batteryCharges(18), passcodeProvider: { "passcode" })

        XCTAssertNil(hash)
        XCTAssertEqual(relayer.emulated, [batteryId])
        XCTAssertEqual(signer.signed.map(\.id), ["bcef74e1-b940-4142-b7a7-76161850971e"])
        XCTAssertEqual(relayer.sent, [FakeSigner.signature])
    }

    func test_aTokenSwapIsEmulatedUnderTheRelayersAssetId() async throws {
        _ = try await engine.send(
            context: context(),
            confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 115_304),
            passcodeProvider: { "passcode" }
        )

        XCTAssertEqual(relayer.emulated, [GaslessFixtures.usdtId])
        XCTAssertEqual(relayer.sent.count, 1)
    }

    func test_aTokenConfirmedUnderTheWalletsIdIsEmulatedUnderTheRelayers() async throws {
        walletTokens = [walletToken(walletUSDCId, balance: 5_000_000)]
        relayer.estimations = [estimation(usdcAsset, fee: 115_304)]
        relayer.emulations[GaslessFixtures.usdcId] = .success(emulation(assetId: GaslessFixtures.usdcId, fee: 115_304))

        _ = try await engine.send(
            context: context(),
            confirmed: .token(assetId: walletUSDCId, amount: 115_304),
            passcodeProvider: { "passcode" }
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

        _ = try await engine.send(
            context: context(),
            confirmed: .token(assetId: GaslessFixtures.usdtId, amount: 115_304),
            passcodeProvider: { "passcode" }
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

    func test_gramCannotPayForAnEVMSwap() async {
        await assertSendFails(confirmed: .gram(amountNano: 1)) { failure in
            guard case .internal = failure else {
                return XCTFail("expected an internal failure, got \(failure)")
            }
        }
        XCTAssertTrue(relayer.emulated.isEmpty)
    }

    // MARK: - Helpers

    private func assertSendFails(
        context: MultichainSwapFeeContext? = nil,
        confirmed: MultichainSwapRelayedFee,
        _ check: (MultichainSwapExecutionFailure) -> Void
    ) async {
        do {
            _ = try await engine.send(context: context ?? self.context(), confirmed: confirmed, passcodeProvider: { "passcode" })
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
        Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdtId, name: "USDT", symbol: "USDT", decimals: 6, image: nil, chain: "eth")
    }

    private var usdcAsset: Components.Schemas.GaslessV2Asset {
        Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdcId, name: "USDC", symbol: "USDC", decimals: 6, image: nil, chain: "eth")
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
            expiresAt: Date().addingTimeInterval(10 * 60)
        )
    }

    private func context(
        chain: MultichainChain = .eth,
        spent: BigUInt? = 1_000_000,
        balance: BigUInt = 2_006_121,
        requiresApproval: Bool = false,
        keys: MultichainSwapWallet.Keys = .hd
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
            payload: .evm(EVMSwapRelay(chain: chain, call: call)),
            spentSourceAmount: spent
        )
    }

    private func swapWallet(keys: MultichainSwapWallet.Keys) -> MultichainSwapWallet {
        let state = MultichainWalletState(
            walletId: "multichain-wallet-id",
            addresses: [
                .init(chain: .eth, address: GaslessFixtures.sender),
                .init(chain: .base, address: GaslessFixtures.sender),
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
