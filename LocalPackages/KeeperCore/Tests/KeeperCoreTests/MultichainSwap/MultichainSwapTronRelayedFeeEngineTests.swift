import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import TKBatteryAPI
import TKFeatureFlags
import TonSwift
import TronSwift
import TronSwiftAPI
import XCTest

/// When a relayed TRON swap asks for the passcode, and what it then signs: the resources are quoted
/// again and the transaction fetched from the node first, and the passcode is asked only to sign
/// that very transaction. The node is stubbed over HTTP and the route is a TRX transfer to the
/// aggregator's deposit address.
final class MultichainSwapTronRelayedFeeEngineTests: XCTestCase {
    private static let sender = "TVdW9qX4kyXb9jFoUwXJswtEqKHdn85AVd"
    private static let deposit = "TU1r33n75FL5dShBt13xcJfgBLuahLgTZo"
    private static let amount: BigUInt = 10_000_000
    private static let charges = 5
    private static let instantFeeNano: BigUInt = 100_000_000
    private static let passcode = "1234"
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private let calls = TronSwapCalls()
    /// When the node built the transaction: a minute before the expiration it gave it.
    private var now = Date(timeIntervalSince1970: TimeInterval(TronNodeStub.expiration - 60000) / 1000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        TronNodeStub.calls = calls
        TronNodeStub.owner = try TronSwift.Address(address: Self.sender).raw
        TronNodeStub.deposit = try TronSwift.Address(address: Self.deposit).raw
    }

    override func tearDown() {
        TronNodeStub.calls = nil
        TronNodeStub.refusesTransaction = false
        super.tearDown()
    }

    func test_aBatterySwapFetchesTheTransactionBeforeThePasscode() async throws {
        try await assertTheTransactionIsFetchedBeforeThePasscode(confirmed: .batteryCharges(Self.charges))
    }

    func test_aGramSwapFetchesTheTransactionBeforeThePasscode() async throws {
        try await assertTheTransactionIsFetchedBeforeThePasscode(confirmed: .gram(amountNano: Self.instantFeeNano))
    }

    func test_whatIsRelayedIsTheTransactionThePreparedSwapDescribes() async throws {
        let wallet = multichainWallet()
        let engine = try await makeEngine(wallet: wallet)
        let prepared = try await engine.prepare(context: context(swapWallet(of: wallet)), confirmed: .batteryCharges(Self.charges))
        let signables = try await prepared.signables(Self.intent)
        let signable = try XCTUnwrap(signables.first)
        let prebuild = try XCTUnwrap(signable.operation.payloads.first?.meta as? PayloadMetaTronPrebuild)
        let reviewed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(prebuild.data.utf8)) as? [String: Any])

        let txID = try await prepared.send(.mnemonic(passcodeProvider: { Self.passcode }))

        let relayed = try XCTUnwrap(calls.relayed.first)
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(Data(base64Encoded: relayed))) as? [String: Any])
        XCTAssertEqual(calls.relayed.count, 1)
        XCTAssertEqual(calls.recorded.filter { $0 == "/wallet/createtransaction" }.count, 1)
        XCTAssertEqual(txID, reviewed["txID"] as? String)
        XCTAssertEqual(sent["txID"] as? String, reviewed["txID"] as? String)
        XCTAssertEqual(sent["raw_data_hex"] as? String, reviewed["raw_data_hex"] as? String)
        XCTAssertEqual((sent["signature"] as? [String])?.count, 1)
        XCTAssertEqual(signable.operation.id, txID)
        XCTAssertEqual(signable.fidelity, .exactWrap)
        XCTAssertEqual(prepared.expiresAt, Date(timeIntervalSince1970: TimeInterval(TronNodeStub.expiration + 600_000) / 1000))
    }

    /// A node that cannot build the transaction fails the swap in prepare, before any prompt, with
    /// the failure a fetch has always had and as a swap nothing could have relayed.
    func test_aTransactionTheNodeCannotBuildFailsBeforeAnyPrompt() async throws {
        TronNodeStub.refusesTransaction = true
        let wallet = multichainWallet()
        let engine = try await makeEngine(wallet: wallet)

        do {
            _ = try await engine.prepare(context: context(swapWallet(of: wallet)), confirmed: .batteryCharges(Self.charges))
            XCTFail("expected the node's refusal to fail the swap")
        } catch {
            guard case .signingFailed = error else {
                return XCTFail("expected a signing failure, got \(error)")
            }
            XCTAssertFalse(error.mayHaveRelayed)
        }
        XCTAssertEqual(calls.recorded.last, "/wallet/createtransaction")
        XCTAssertTrue(calls.relayed.isEmpty)
    }

    /// The prompt can stay open past the expiration the transaction was built with. It is then not
    /// relayed: the swap fails as an expired payload, which the swap screen quotes again after.
    func test_aTransactionThatExpiredDuringThePromptIsNotRelayed() async throws {
        let wallet = multichainWallet()
        let engine = try await makeEngine(wallet: wallet)
        let prepared = try await engine.prepare(context: context(swapWallet(of: wallet)), confirmed: .batteryCharges(Self.charges))
        let expiresAt = try XCTUnwrap(prepared.expiresAt)

        do {
            _ = try await prepared.send(.mnemonic(passcodeProvider: {
                self.now = expiresAt
                return Self.passcode
            }))
            XCTFail("expected the expired transaction to fail the swap")
        } catch {
            XCTAssertEqual(error, .payloadExpired(payloadId: "main"))
        }
        XCTAssertTrue(calls.relayed.isEmpty)
    }

    func test_aClockAheadOfTheNodeDoesNotRefuseEveryPreparedTransaction() async throws {
        now = now.addingTimeInterval(30 * 60)
        let wallet = multichainWallet()
        let engine = try await makeEngine(wallet: wallet)
        let prepared = try await engine.prepare(context: context(swapWallet(of: wallet)), confirmed: .batteryCharges(Self.charges))

        let txID = try await prepared.send(.mnemonic(passcodeProvider: { Self.passcode }))

        XCTAssertNotNil(txID)
        XCTAssertEqual(calls.relayed.count, 1)
    }

    /// A USDT deposit a route `/v3` prepared, read off its TRC-20 calldata, is priced and relayed as that
    /// transfer: the node is asked for exactly it, and the transaction it builds is signed only if it
    /// matches.
    func test_aTRC20DepositOfARouteV3PreparedIsRelayedAsTheTransferItsCalldataNames() async throws {
        let wallet = multichainWallet()
        let engine = try await makeEngine(wallet: wallet)
        let usdt = MultichainAssetDetails(assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t", name: "Tether USD", symbol: "USDT", decimals: 6, image: "")
        // `transfer(TU1r33n75FL5dShBt13xcJfgBLuahLgTZo, 10000000)`.
        let calldata = "a9059cbb000000000000000000000000c5f202be12eacb33530e88a6915e7dbb127670410000000000000000000000000000000000000000000000000000000000989680"
        let operation = try ChainKitOperationSender.parse(
            id: "route",
            payloads: #"[{"chain_id":"tron/mainnet","id":"deposit","type":"main","version":1,"meta":{"to":"TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t","value":"0","data":"\#(calldata)"}}]"#
        )
        let sold = MultichainAsset(asset: usdt, price: .init(prices: [:], diff24h: [:], diff7d: [:]), balance: 100_000_000)
        let payload = try XCTUnwrap(MultichainSwapBatteryPayload(relaying: operation, selling: sold, from: Self.sender))
        let context = context(swapWallet(of: wallet), selling: usdt, payload: payload)

        let options = await engine.options(context: context)
        let prepared = try await engine.prepare(context: context, confirmed: .batteryCharges(Self.charges))
        _ = try await prepared.send(.mnemonic(passcodeProvider: { Self.passcode }))

        XCTAssertEqual(payload, .tron(TronSwapTransfer(to: Self.deposit, amount: Self.amount)))
        XCTAssertEqual(options.first?.method, .battery)
        XCTAssertEqual(calls.recorded.filter { $0 == "/wallet/triggersmartcontract" }.count, 1)
        XCTAssertEqual(calls.relayed.count, 1)
    }

    /// A legacy wallet has no multichain state: the swap spends from the TRON address it swaps with,
    /// whose key is not stored.
    func test_aLegacyWalletIsReviewedFromItsOwnTronAddress() async throws {
        let wallet = legacyWallet()
        let swapWallet = try XCTUnwrap(wallet.legacySwapWallet)
        let tron = try XCTUnwrap(swapWallet.walletAddress(for: .tron))
        TronNodeStub.owner = try TronSwift.Address(address: tron.address).raw
        let engine = try await makeEngine(wallet: wallet)

        let prepared = try await engine.prepare(context: context(swapWallet), confirmed: .batteryCharges(Self.charges))
        let signables = try await prepared.signables(Self.intent)
        let account = try XCTUnwrap(signables.first).account

        XCTAssertEqual(account.addressDisplay, tron.address)
        XCTAssertNil(account.publicKey)
        XCTAssertEqual(account.asset.id, "tron/mainnet/coin")
    }
}

private extension MultichainSwapTronRelayedFeeEngineTests {
    static let intent = OperationIntent.wallet(
        spending: [OperationIntent.Spend(assetId: "tron/mainnet/coin", symbol: "TRX", decimals: 6, amount: amount)],
        to: nil
    )

    func assertTheTransactionIsFetchedBeforeThePasscode(
        confirmed: MultichainSwapRelayedFee,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let wallet = multichainWallet()
        let engine = try await makeEngine(wallet: wallet)

        let prepared = try await engine.prepare(context: context(swapWallet(of: wallet)), confirmed: confirmed)

        XCTAssertTrue(calls.recorded.contains("/wallet/getaccountnet"), "the resources are quoted again first", file: file, line: line)
        XCTAssertEqual(calls.recorded.last, "/wallet/createtransaction", file: file, line: line)
        do {
            _ = try await prepared.send(.mnemonic(passcodeProvider: { [calls] in
                calls.record("passcode")
                return nil
            }))
            XCTFail("expected the declined passcode to cancel the swap", file: file, line: line)
        } catch {
            guard case .canceled = error else {
                return XCTFail("expected a cancellation, got \(error)", file: file, line: line)
            }
        }
        XCTAssertEqual(calls.recorded.last, "passcode", file: file, line: line)
        XCTAssertTrue(calls.relayed.isEmpty, file: file, line: line)
    }

    func makeEngine(wallet: Wallet) async throws -> MultichainSwapTronRelayedFeeEngine {
        let session = TronNodeStub.session()
        // A configuration that never answered keeps TRON in the TRX-only region, where nothing is relayed.
        let mainnet = try JSONDecoder().decode(BootConfiguration.self, from: Data(#"{"flags": {"trx_only_region": false}}"#.utf8))
        let configuration = KeeperCore.Configuration(
            bootConfigurationService: BootConfigurationServiceStub(
                bootConfigurations: BootConfigurations(mainnet: mainnet, testnet: .empty)
            ),
            featureFlags: DummyFeatureFlags(),
            tkAppSettings: AppSettingsStub()
        )
        let batteryService = BatteryServiceStub(
            calls: calls,
            estimate: TKBatteryAPI.Components.Schemas.EstimatedTronTx(
                energy_charges: 0,
                bandwidth_charges: Self.charges,
                activation_charges: 0,
                total_charges: Self.charges,
                instant_fee: .init(
                    fee_address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
                    accepted_assets: [
                        .init(_type: .ton, name: "GRAM", amount_nano: Self.instantFeeNano.description, decimals: 9),
                    ]
                )
            )
        )
        let chainParameters = TronChainParametersRepositoryImplementation()
        await chainParameters.setChainFees(
            TronChainFees(energySun: 100, bandwidthSun: 1000, createAccountSun: 100_000, createNewAccountSun: 1_000_000, createNewAccountBandwidthRate: 1)
        )
        let mnemonicAccess = MnemonicAccess.inMemory(seed: "tron-relayed-fee-engine")
        try await mnemonicAccess.saveMnemonic(
            CoreMnemonic(mnemonicWords: Self.mnemonic.components(separatedBy: " "), type: .bip39),
            wallet: wallet,
            passcode: Self.passcode
        )
        return try MultichainSwapTronRelayedFeeEngine(
            tronUsdtApi: TronUSDTAPI(
                tronApi: TronApi(urlSession: session, baseApiUrl: XCTUnwrap(URL(string: "https://tron.test")), pause: { _ in }),
                batteryAPI: BatteryAPI(hostProvider: BatteryHostStub(), urlSession: session),
                batteryService: batteryService,
                chainParametersRepository: chainParameters
            ),
            sendService: SendServiceStub(),
            balanceService: BalanceServiceStub(),
            batteryService: batteryService,
            batteryCalculation: BatteryCalculation(configuration: configuration),
            configuration: configuration,
            chainKitService: ChainKitServiceImplementation(
                supportedChains: [.tron],
                mnemonicAccess: mnemonicAccess,
                client: CryptoKitClient(
                    netModule: ModuleNetModule(
                        netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
                    )
                ),
                gate: OperationGate { [] }
            ),
            mnemonicAccess: mnemonicAccess,
            now: { self.now }
        )
    }

    func context(
        _ swapWallet: MultichainSwapWallet,
        selling asset: MultichainAssetDetails = MultichainAssetDetails(assetId: "tron/mainnet/coin", name: "TRON", symbol: "TRX", decimals: 6, image: ""),
        payload: MultichainSwapBatteryPayload = .tron(TronSwapTransfer(
            to: MultichainSwapTronRelayedFeeEngineTests.deposit,
            amount: MultichainSwapTronRelayedFeeEngineTests.amount
        ))
    ) -> MultichainSwapFeeContext {
        MultichainSwapFeeContext(
            swapWallet: swapWallet,
            sourceAsset: MultichainAsset(
                asset: asset,
                price: .init(prices: [:], diff24h: [:], diff7d: [:]),
                balance: 100_000_000
            ),
            payloadId: "main",
            requiresApproval: false,
            payload: payload,
            spentSourceAmount: Self.amount
        )
    }

    func multichainWallet() -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: .init(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(MultichainWalletState(
                walletId: "multichain-wallet-id",
                addresses: [.init(chain: .tron, address: Self.sender)]
            ))
        )
    }

    func swapWallet(of wallet: Wallet) -> MultichainSwapWallet {
        MultichainSwapWallet(
            wallet: wallet,
            addresses: [.init(chain: .tron, address: Self.sender)],
            registration: .registered(walletId: "multichain-wallet-id"),
            keys: .hd
        )
    }
}

private struct BootConfigurationServiceStub: BootConfigurationService {
    let bootConfigurations: BootConfigurations

    func getConfiguration() throws -> BootConfigurations {
        bootConfigurations
    }

    func loadConfiguration() async throws -> BootConfigurations {
        bootConfigurations
    }
}

private final class AppSettingsStub: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
}
