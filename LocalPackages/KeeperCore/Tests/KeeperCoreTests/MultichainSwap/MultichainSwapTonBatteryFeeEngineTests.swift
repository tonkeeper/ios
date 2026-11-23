import ChainKit
import Foundation
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import TonSwift
import XCTest

/// What a battery-relayed TON swap builds before the passcode and what it then signs. The route is
/// one message of a jetton sale to a router; see `TonBatteryRelayFixture` for what is stubbed.
final class MultichainSwapTonBatteryFeeEngineTests: XCTestCase {
    private static let passcode = "1234"
    private static let words = [
        "business", "thunder", "episode", "arena",
        "tray", "twelve", "humble", "asthma",
        "uphold", "pumpkin", "crunch", "fortune",
    ]
    private static let charges = 10
    private static let jettonId = "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
    private static let intent = OperationIntent.wallet(
        spending: [OperationIntent.Spend(assetId: jettonId, symbol: "USDT", decimals: 6, amount: 1_000_000)],
        to: nil
    )

    private lazy var mnemonicAccess: MnemonicAccess = .inMemory(seed: "ton-battery-fee-engine")

    private lazy var chainKitService = ChainKitServiceImplementation(
        supportedChains: [.ton],
        mnemonicAccess: mnemonicAccess,
        client: CryptoKitClient(
            netModule: ModuleNetModule(
                netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
            )
        ),
        gate: OperationGate { [] }
    )

    func test_aSwapIsBuiltBeforeThePasscodeAndSignedAsItWasBuilt() async throws {
        let fixture = try TonBatteryRelayFixture()
        let wallet = try multichainWallet()
        let swapWallet = try MultichainSwapWallet(wallet: wallet, registeredState: XCTUnwrap(wallet.multichainWalletState))
        let engine = try await makeEngine(fixture, wallet: wallet)

        let prepared = try await engine.prepare(context: context(swapWallet), confirmed: .batteryCharges(Self.charges))

        XCTAssertTrue(fixture.calls.relayed.isEmpty)
        let signables = try await prepared.signables(Self.intent)
        let signable = try XCTUnwrap(signables.first)
        let request = try XCTUnwrap(signable.operation.payloads.first?.meta as? PayloadMetaTonPrebuild)

        let hash = try await prepared.send(.mnemonic(passcodeProvider: { [calls = fixture.calls] in
            calls.record("passcode")
            return Self.passcode
        }))

        XCTAssertEqual(fixture.calls.recorded.suffix(2), ["passcode", "relay"])
        XCTAssertEqual(fixture.calls.relayed.count, 1)
        let relayed = try XCTUnwrap(fixture.calls.relayed.first)
        XCTAssertEqual(hash, try TonMessageHash.hex(signedBocBase64: relayed))
        XCTAssertEqual(try signedRequest(of: relayed).hash(), try Cell.fromBase64(src: request.data).hash())
        XCTAssertEqual(signable.fidelity, .exactWrap)
        XCTAssertEqual(prepared.expiresAt, Date(timeIntervalSince1970: TimeInterval(TonBatteryRelayFixture.timeout)))
        let proof = try XCTUnwrap(chainKitService.batterySendProof(wallet: wallet, mnemonic: Self.words.joined(separator: " "), boc: relayed))
        XCTAssertEqual(fixture.calls.proofs, [proof])
    }

    /// A W5 wallet's swap reaches the chain inside the relayer's own message, so it is known by that message's hash.
    func test_aW5SwapIsKnownByTheRelayersMessage() async throws {
        let fixture = try TonBatteryRelayFixture()
        fixture.calls.relayerMessageHash = "relayer"
        let wallet = try multichainWallet(.v5R1)
        let swapWallet = try MultichainSwapWallet(wallet: wallet, registeredState: XCTUnwrap(wallet.multichainWalletState))
        let engine = try await makeEngine(fixture, wallet: wallet)
        let prepared = try await engine.prepare(context: context(swapWallet), confirmed: .batteryCharges(Self.charges))

        let hash = try await prepared.send(.mnemonic(passcodeProvider: { Self.passcode }))

        XCTAssertEqual(hash, "relayer")
    }

    /// TonSwift writes the cells of a W5 request in an order a `Set` picks, so the request is written
    /// once and every review of one prepared swap reads the same operation. A request written on
    /// every review fails this test in about half of the runs, not in each.
    func test_everyReviewOfAPreparedSwapReadsTheSameRequest() async throws {
        let fixture = try TonBatteryRelayFixture()
        let wallet = try multichainWallet(.v5R1)
        let swapWallet = try MultichainSwapWallet(wallet: wallet, registeredState: XCTUnwrap(wallet.multichainWalletState))
        let engine = try await makeEngine(fixture, wallet: wallet)
        let prepared = try await engine.prepare(context: context(swapWallet), confirmed: .batteryCharges(Self.charges))

        var reviews = [SignableOperation]()
        for _ in 0 ..< 8 {
            reviews += try await prepared.signables(Self.intent)
        }

        XCTAssertEqual(Set(reviews.map(\.operation.meta)).count, 1)
    }

    /// The emulation that prices the swap reads the seqno first: a second read that fails leaves
    /// the transfer unprepared, before anything could reach the battery.
    func test_aTransferThatCannotBePreparedIsNotRelayed() async throws {
        let fixture = try TonBatteryRelayFixture()
        let wallet = try multichainWallet()
        let swapWallet = try MultichainSwapWallet(wallet: wallet, registeredState: XCTUnwrap(wallet.multichainWalletState))
        let engine = try await makeEngine(fixture, wallet: wallet, seqnoReads: 1)

        do {
            _ = try await engine.prepare(context: context(swapWallet), confirmed: .batteryCharges(Self.charges))
            XCTFail("expected the unread seqno to fail the swap")
        } catch {
            guard case .preparationFailed(kind: .internalError, _) = error else {
                return XCTFail("expected a preparation failure, got \(error)")
            }
            XCTAssertFalse(error.mayHaveRelayed)
        }
        XCTAssertEqual(fixture.calls.recorded, ["seqno", "seqno"])
        XCTAssertTrue(fixture.calls.relayed.isEmpty)
    }

    func test_aDeclinedPasscodeRelaysNothing() async throws {
        let fixture = try TonBatteryRelayFixture()
        let wallet = try multichainWallet()
        let swapWallet = try MultichainSwapWallet(wallet: wallet, registeredState: XCTUnwrap(wallet.multichainWalletState))
        let engine = try await makeEngine(fixture, wallet: wallet)
        let prepared = try await engine.prepare(context: context(swapWallet), confirmed: .batteryCharges(Self.charges))

        do {
            _ = try await prepared.send(.mnemonic(passcodeProvider: { nil }))
            XCTFail("expected the declined passcode to cancel the swap")
        } catch {
            guard case .canceled = error else {
                return XCTFail("expected a cancellation, got \(error)")
            }
        }
        XCTAssertTrue(fixture.calls.relayed.isEmpty)
    }

    /// A legacy wallet has no multichain state: the swap spends from the TON address it swaps with.
    func test_aLegacyWalletIsReviewedFromItsOwnTonAddress() async throws {
        let fixture = try TonBatteryRelayFixture()
        let wallet = try legacyWallet()
        let swapWallet = try XCTUnwrap(wallet.legacySwapWallet)
        let engine = try await makeEngine(fixture, wallet: wallet)

        let prepared = try await engine.prepare(context: context(swapWallet), confirmed: .batteryCharges(Self.charges))
        let signables = try await prepared.signables(Self.intent)
        let account = try XCTUnwrap(signables.first).account

        let ton = try XCTUnwrap(swapWallet.walletAddress(for: .ton))
        XCTAssertEqual(account.addressDisplay, ton.address)
        XCTAssertEqual(account.address.type, .tonv4r2)
        XCTAssertEqual(account.publicKey?.defaultHex, ton.publicKey?.defaultHex)
        XCTAssertEqual(account.asset.id, Self.jettonId)
    }
}

private extension MultichainSwapTonBatteryFeeEngineTests {
    /// The request inside a signed v4R2 external message, its signature in front of it.
    func signedRequest(of boc: String) throws -> Cell {
        let message = try TonSwift.Message.loadFrom(slice: Cell.fromBase64(src: boc).beginParse())
        let body = try message.body.beginParse()
        try body.skip(512)
        return try body.loadRemainder()
    }

    func makeEngine(
        _ fixture: TonBatteryRelayFixture,
        wallet: Wallet,
        seqnoReads: Int = .max
    ) async throws -> MultichainSwapTonBatteryFeeEngine {
        try await mnemonicAccess.saveMnemonic(
            CoreMnemonic(mnemonicWords: Self.words, type: .ton),
            wallet: wallet,
            passcode: Self.passcode
        )
        return MultichainSwapTonBatteryFeeEngine(
            transferService: fixture.transferService(seqnoReads: seqnoReads),
            balanceService: fixture.balanceService,
            batteryService: fixture.batteryService,
            batteryCalculation: BatteryCalculation(configuration: fixture.configuration),
            configuration: fixture.configuration,
            chainKitService: chainKitService,
            mnemonicAccess: mnemonicAccess
        )
    }

    func context(_ swapWallet: MultichainSwapWallet) -> MultichainSwapFeeContext {
        MultichainSwapFeeContext(
            swapWallet: swapWallet,
            sourceAsset: MultichainAsset(
                asset: MultichainAssetDetails(assetId: Self.jettonId, name: "Tether USD", symbol: "USD₮", decimals: 6, image: ""),
                price: .init(prices: [:], diff24h: [:], diff7d: [:]),
                balance: 5_000_000
            ),
            payloadId: "main",
            requiresApproval: false,
            payload: .ton([
                TonSwapMessage(
                    to: "0:0000000000000000000000000000000000000000000000000000000000000002",
                    amount: 300_000_000,
                    payload: nil,
                    stateInit: nil
                ),
            ]),
            spentSourceAmount: 1_000_000
        )
    }

    func publicKey() throws -> TonSwift.PublicKey {
        try CoreMnemonic(mnemonicWords: Self.words, type: .ton).toKeyPair().publicKey
    }

    func multichainWallet(_ version: WalletContractVersion = .v4R2) throws -> Wallet {
        let publicKey = try publicKey()
        let identity = WalletIdentity(network: .mainnet, kind: .Regular(publicKey, version))
        let unregistered = Wallet(
            id: "ton-battery-multichain",
            identity: identity,
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
        let state = try MultichainWalletState(
            walletId: "ton-battery-multichain",
            addresses: [
                MultichainWalletAddress(
                    chain: .ton,
                    address: unregistered.friendlyAddress.toString(),
                    type: version == .v5R1 ? .tonV5R1 : .tonV4R2,
                    publicKey: MultichainPublicKey(
                        defaultHex: "0x" + publicKey.data.map { String(format: "%02hhx", $0) }.joined(),
                        segWit: ""
                    )
                ),
            ]
        )
        return Wallet(
            id: unregistered.id,
            identity: identity,
            metaData: unregistered.metaData,
            setupSettings: unregistered.setupSettings,
            batterySettings: unregistered.batterySettings,
            multichain: .multichain(state)
        )
    }

    func legacyWallet() throws -> Wallet {
        try Wallet(
            id: "ton-battery-legacy",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey(), .v4R2)),
            metaData: WalletMetaData(label: "Legacy", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            tron: WalletTron(tonMnemonic: Self.words)
        )
    }
}
