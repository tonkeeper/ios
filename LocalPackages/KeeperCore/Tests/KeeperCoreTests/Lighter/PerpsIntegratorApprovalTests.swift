import ChainKit
import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import KeeperCoreSensitive
import PerpsModels
import TKKeychain
import TKPerpsAPI
import TonSwift
import XCTest

final class PerpsIntegratorApprovalTests: XCTestCase {
    private let session = PerpsAccountSession(accountIndex: 748_924, apiKeyIndex: 3)

    func testARecordedApprovalIsNotSignedAgain() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try credentials(vault, wallet).saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsServerClock.shared.serverNowUnixMs() + 30 * 86_400_000)
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper), vault: vault)

        try await service.ensureIntegratorApproval(
            wallet: wallet,
            session: session,
            nonceCoordinator: PerpsNonceCoordinator(),
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 0)
    }

    func testAMissingApprovalAsksForThePasscodeAndACancelSendsNothing() async throws {
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper))

        do {
            try await service.ensureIntegratorApproval(
                wallet: makeWallet(),
                session: session,
                nonceCoordinator: PerpsNonceCoordinator(),
                passcodeProvider: { await prompts.cancel() }
            )
            XCTFail("a canceled passcode must not approve")
        } catch {
            XCTAssertEqual(error as? PerpsTradingError, .activationCanceled)
        }

        let count = await prompts.count
        XCTAssertEqual(count, 1)
    }

    func testAnUnreadableRecordIsSignedAgainInsteadOfFailingEveryTrade() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try vault.set(
            Data("not an approval".utf8),
            query: TKKeychainQuery(
                item: .genericPassword(
                    service: "LighterCredentials",
                    account: "\(wallet.id)/\(PerpsEnvironment.storage)/integratorApproval"
                ),
                accessGroup: nil,
                biometry: .none,
                accessible: .whenUnlockedThisDeviceOnly
            )
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper), vault: vault)

        do {
            try await service.ensureIntegratorApproval(
                wallet: wallet,
                session: session,
                nonceCoordinator: PerpsNonceCoordinator(),
                passcodeProvider: { await prompts.cancel() }
            )
            XCTFail("a canceled passcode must not approve")
        } catch {
            XCTAssertEqual(error as? PerpsTradingError, .activationCanceled)
        }

        let count = await prompts.count
        XCTAssertEqual(count, 1)
    }

    func testAnApprovalAboutToExpireIsSignedAgain() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try credentials(vault, wallet).saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsServerClock.shared.serverNowUnixMs() + 3_600_000)
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper), vault: vault)

        _ = try? await service.ensureIntegratorApproval(
            wallet: wallet,
            session: session,
            nonceCoordinator: PerpsNonceCoordinator(),
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 1)
    }

    func testAShortLivedApprovalIsKeptForMostOfItsLife() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try credentials(vault, wallet).saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsServerClock.shared.serverNowUnixMs() + 3 * 3_600_000)
        )
        let prompts = PromptCount()
        let service = makeService(
            api: AccountStubAPI(account: .init(), integrator: .tonkeeper(approvalTtlMs: 4 * 3_600_000)),
            vault: vault
        )

        try await service.ensureIntegratorApproval(
            wallet: wallet,
            session: session,
            nonceCoordinator: PerpsNonceCoordinator(),
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 0)
    }

    func testARaisedFeeCeilingIsSignedAgain() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        try credentials(vault, wallet).saveIntegratorApproval(
            PerpsIntegratorApproval(
                key: approvalKey(maxPerpsTakerFee: 900),
                expiry: PerpsServerClock.shared.serverNowUnixMs() + 30 * 86_400_000
            )
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .tonkeeper), vault: vault)

        _ = try? await service.ensureIntegratorApproval(
            wallet: wallet,
            session: session,
            nonceCoordinator: PerpsNonceCoordinator(),
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 1)
    }

    func testAnIntegratorSwitchedOffForgetsTheApproval() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        let store = credentials(vault, wallet)
        try store.saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsServerClock.shared.serverNowUnixMs() + 30 * 86_400_000)
        )
        let prompts = PromptCount()
        let service = makeService(api: AccountStubAPI(account: .init(), integrator: .none), vault: vault)

        try await service.ensureIntegratorApproval(
            wallet: wallet,
            session: session,
            nonceCoordinator: PerpsNonceCoordinator(),
            passcodeProvider: { await prompts.cancel() }
        )

        let count = await prompts.count
        XCTAssertEqual(count, 0)
        XCTAssertNil(try store.loadIntegratorApproval())
    }

    func testAnOrderRefusedAfterAcceptedLeverageAsksForApprovalAndACancelClearsThePending() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet(id: UUID().uuidString)
        let store = credentials(vault, wallet)
        let privateKey = Data(repeating: 0xAB, count: 40)
        try store.saveL2PrivateKey(privateKey)
        try store.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex, keyDerivationIndex: 0))
        try store.saveIntegratorApproval(
            PerpsIntegratorApproval(key: approvalKey(), expiry: PerpsServerClock.shared.serverNowUnixMs() + 30 * 86_400_000)
        )
        let privateKeyHex = privateKey.map { String(format: "%02x", $0) }.joined()
        let sent = SentApprovals()
        let api = AccountStubAPI(
            account: .init(),
            integrator: .tonkeeper,
            nonce: 287,
            tradingScreen: .init(
                market: .init(
                    market_index: 1, symbol: "ETH", quote_asset: "USDC", status: "active",
                    price_decimals: 2, size_decimals: 4, tick_size: "0.01", step_size: "0.0001", min_size_base: "0.001",
                    maker_fee_pct: "0.02", taker_fee_pct: "0.04", initial_margin_fraction: 400,
                    maintenance_margin_fraction: 300, mark_price: "2000"
                ),
                open_orders: [],
                balance: .init(available_balance: "1000"),
                flags: .init(open_enabled: true, cancel_enabled: true)
            ),
            orderBook: .init(
                updated_at: Date(), truncated: true,
                bids: [.init(price: "1999", size: "10")], asks: [.init(price: "2000", size: "10")]
            ),
            onSendTransactions: { transactions in
                await sent.record(transactions)
                guard transactions[0].tx_type == LighterConstants.shared.TxTypeL2UpdateLeverage else {
                    throw PerpsAPIError.badStatus(.init(
                        httpStatus: 400, code: "validation_error", message: nil,
                        retryable: false, reason: "integrator_not_approved"
                    ))
                }
                let hash = try await Self.transactionHash(transactions[0], privateKeyHex: privateKeyHex)
                return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: hash)])
            }
        )
        let service = makeService(api: api, vault: vault)
        let trading = PerpsTkTradingService(
            accountService: service, wallet: wallet, perpsAPI: api,
            markPriceProvider: { _ in nil }, marketProvider: { _ in nil },
            nonceCoordinator: PerpsNonceCoordinator()
        )
        let prepared = try await trading.prepareOpenMarket(.init(
            marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01, autoClose: nil
        )).get()
        let prompts = PromptCount()

        let result = await trading.submit(prepared, passcodeProvider: { await prompts.cancel() })

        if case let .failed(error) = result {
            XCTAssertEqual(error, .activationCanceled)
        } else {
            XCTFail("a refused order must request approval even after leverage was accepted")
        }
        let promptCount = await prompts.count
        let transactions = await sent.transactions
        let journal = service.pendingJournal(wallet: wallet)
        let pending = try await journal.pending(operationId: prepared.operationId)
        XCTAssertEqual(promptCount, 1)
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions.first?.tx_type, LighterConstants.shared.TxTypeL2UpdateLeverage)
        XCTAssertNil(pending)
        XCTAssertNil(try store.loadIntegratorApproval())
        try await journal.removePending(operationId: prepared.operationId)
    }

    func testTheApprovalCarriesTheOwnerSignatureAndIsRecorded() async throws {
        let vault = InMemoryKeychainVault()
        let wallet = makeWallet()
        let mnemonicAccess = makeMnemonicAccess(vault: vault)
        try await mnemonicAccess.saveMnemonic(
            CoreMnemonic(mnemonicWords: Self.mnemonic.components(separatedBy: " "), type: .bip39),
            wallet: wallet,
            passcode: "1234"
        )
        let store = credentials(vault, wallet)
        try await store.keepTradingKey(cryptoWallet: CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.mnemonic))
        let privateKeyHex = try XCTUnwrap(store.loadL2PrivateKey()).map { String(format: "%02x", $0) }.joined()
        let sent = SentApprovals()
        let api = AccountStubAPI(
            account: .init(),
            integrator: .tonkeeper,
            nonce: 287,
            onSendTransactions: { transactions in
                await sent.record(transactions)
                let hash = try await Self.transactionHash(transactions[0], privateKeyHex: privateKeyHex)
                return .init(transactions: [.init(tx_type: transactions[0].tx_type, tx_hash: hash)])
            }
        )
        let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
        let nonceCoordinator = PerpsNonceCoordinator()
        // An order Lighter refused has already taken 287 without using it.
        _ = try await nonceCoordinator.next(
            scope: .init(
                environment: PerpsEnvironment.venue,
                accountIndex: session.accountIndex,
                apiKeyIndex: session.apiKeyIndex,
                chainId: LighterConstants.shared.ChainId
            )
        ) { 287 }

        try await service.ensureIntegratorApproval(
            wallet: wallet,
            session: session,
            nonceCoordinator: nonceCoordinator,
            passcodeProvider: { "1234" }
        )

        let transactions = await sent.transactions
        XCTAssertEqual(transactions.map(\.tx_type), [Int32(LighterConstants.shared.TxTypeL2ApproveIntegrator)])
        let txInfo = try Self.json(transactions[0].tx_info)
        XCTAssertEqual((txInfo["Nonce"] as? NSNumber)?.int64Value, 287)
        let l1Signature = try XCTUnwrap(txInfo["L1Sig"] as? String)
        XCTAssertTrue(l1Signature.hasPrefix("0x"))
        XCTAssertEqual(l1Signature.count, 132)
        let recorded = try XCTUnwrap(store.loadIntegratorApproval())
        XCTAssertEqual(recorded.key, approvalKey())
        XCTAssertEqual(recorded.expiry, (txInfo["ApprovalExpiry"] as? NSNumber)?.int64Value)
    }
}

private extension PerpsIntegratorApprovalTests {
    static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    func approvalKey(maxPerpsTakerFee: Int = 1000) -> PerpsIntegratorApprovalKey {
        PerpsIntegratorApprovalKey(
            accountIndex: session.accountIndex,
            integratorAccountIndex: Components.Schemas.Integrator.tonkeeper.integrator_account_index,
            maxPerpsTakerFee: maxPerpsTakerFee,
            maxPerpsMakerFee: 1000,
            maxSpotTakerFee: 0,
            maxSpotMakerFee: 0
        )
    }

    func credentials(_ vault: InMemoryKeychainVault, _ wallet: Wallet) -> LighterCredentialsStore {
        LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
    }

    func makeMnemonicAccess(vault: InMemoryKeychainVault) -> MnemonicAccess {
        .disabled(mnemonicsRepository: .init(
            rn: RNMnemonicsVault(keychainVault: vault),
            native: MnemonicsVault(keychainVault: vault, seedProvider: { "integrator-approval" })
        ))
    }

    func makeService(
        api: PerpsAPI,
        vault: InMemoryKeychainVault = InMemoryKeychainVault(),
        mnemonicAccess: MnemonicAccess? = nil
    ) -> PerpsAccountService {
        let client = CryptoKitClient(netModule: ModuleNetModule(netConfig: ModuleNetConfig(
            isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil
        )))
        return PerpsAccountService(
            mnemonicAccess: mnemonicAccess ?? makeMnemonicAccess(vault: vault),
            keychainVault: vault,
            perpsAPI: api,
            bindSigner: PerpsAccountBindSigner(client: client),
            walletAuthTokenProvider: ApprovalUnusedWalletAuth(),
            chainKitClient: client
        )
    }

    func makeWallet(id: String = "perps-integrator-approval") -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: WalletMetaData(label: "Perps", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: id,
                addresses: [.init(chain: .eth, address: "0x9858effd232b4033e47d90003d41ec34ecaeda94")],
                syncState: .synced
            ))
        )
    }

    static func json(_ text: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    static func transactionHash(_ signed: Components.Schemas.SignedTransaction, privateKeyHex: String) async throws -> String {
        let fields = try json(signed.tx_info)
        func int64(_ name: String) throws -> Int64 {
            try XCTUnwrap((fields[name] as? NSNumber)?.int64Value)
        }
        let client = try LighterClient(
            crypto: LighterCryptoBridge(crypto: CoreLighterCrypto()),
            nowMillis: { KotlinLong(value: 0) }
        ).doNewTxClient(
            privateKeyHex: privateKeyHex,
            accountIndex: int64("AccountIndex"),
            apiKeyIndex: Int32(int64("ApiKeyIndex")),
            chainId: LighterConstants.shared.ChainId
        )
        let options = try LighterTransactOpts(
            fromAccountIndex: nil,
            apiKeyIndex: nil,
            expiredAt: int64("ExpiredAt"),
            nonce: KotlinLong(value: int64("Nonce")),
            attributes: nil,
            dryRun: false
        )
        if signed.tx_type == LighterConstants.shared.TxTypeL2UpdateLeverage {
            let request = try LighterUpdateLeverageTxReq(
                marketIndex: Int16(int64("MarketIndex")),
                initialMarginFraction: Int32(int64("InitialMarginFraction")),
                marginMode: Int32(int64("MarginMode"))
            )
            let transaction: L2UpdateLeverageTxInfo = try await bridgeKotlin { completion in
                client.getUpdateLeverageTransaction(req: request, ops: options, completionHandler: completion)
            }
            return transaction.getTxHash()
        }
        let request = try LighterApproveIntegratorTxReq(
            integratorAccountIndex: int64("IntegratorAccountIndex"),
            maxPerpsTakerFee: Int32(int64("MaxPerpsTakerFee")),
            maxPerpsMakerFee: Int32(int64("MaxPerpsMakerFee")),
            maxSpotTakerFee: Int32(int64("MaxSpotTakerFee")),
            maxSpotMakerFee: Int32(int64("MaxSpotMakerFee")),
            approvalExpiry: int64("ApprovalExpiry")
        )
        let transaction: L2ApproveIntegratorTxInfo = try await bridgeKotlin { completion in
            client.getApproveIntegratorTransaction(req: request, ops: options, l1Signer: nil, completionHandler: completion)
        }
        return transaction.getTxHash()
    }
}

private extension Components.Schemas.Integrator {
    static var tonkeeper: Self {
        tonkeeper(approvalTtlMs: 31_536_000_000)
    }

    static func tonkeeper(approvalTtlMs: Int64) -> Self {
        .init(
            integrator_account_index: 281_474_976_487_764,
            integrator_taker_fee: 900,
            integrator_maker_fee: 900,
            max_perps_taker_fee: 1000,
            max_perps_maker_fee: 1000,
            max_spot_taker_fee: 0,
            max_spot_maker_fee: 0,
            approval_ttl_ms: approvalTtlMs
        )
    }
}

private actor PromptCount {
    private(set) var count = 0

    func cancel() -> String? {
        count += 1
        return nil
    }
}

private actor SentApprovals {
    private(set) var transactions: [Components.Schemas.SignedTransaction] = []

    func record(_ sent: [Components.Schemas.SignedTransaction]) {
        transactions.append(contentsOf: sent)
    }
}

private struct ApprovalUnusedWalletAuth: WalletAuthTokenProviding {
    func token(walletId _: String, accessToken _: String) async -> String? {
        nil
    }

    func invalidateToken(walletId _: String) async {}
    func hasPersistentAppKey(walletId _: String) async -> Bool {
        false
    }

    func warm(walletId _: String, mnemonic _: String) async {}
    func persistAppKey(_: Data, walletId _: String) async {}
    func forget(walletId _: String) async {}
    func wipe() async {}
}
