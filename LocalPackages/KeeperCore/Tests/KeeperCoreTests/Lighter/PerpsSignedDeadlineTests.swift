import ChainKit
import Foundation
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import PerpsModels
import TKPerpsAPI
import TonSwift
import XCTest

/// The backend picks the `Date` header; a deadline signed from it would live as long as the backend chose.
final class PerpsSignedDeadlineTests: XCTestCase {
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let yearMillis: Int64 = 365 * 86_400_000
    private static let dateHeaders: [(skewMs: Int64, signedShiftMs: Int64)] = [
        (yearMillis, 0),
        (-yearMillis, 0),
        (-30000, -30000),
        (30000, 30000),
    ]
    private let session = PerpsAccountSession(accountIndex: 748_924, apiKeyIndex: 3)

    override func tearDown() {
        PerpsServerClock.shared.record(serverDate: Date())
        super.tearDown()
    }

    func testLighterAuthorizationsLiveFromTheSigningClock() async throws {
        for header in Self.dateHeaders {
            recordDateHeader(skewMs: header.skewMs)
            let auths = SignedAuths()
            let api = AccountStubAPI(
                account: .init(),
                onIssueReadOnlyToken: {},
                onAccountTier: { .init(id: "0", name: "standard") },
                onChangeAccountTier: { _ in },
                onLighterAuth: { await auths.record($0) }
            )
            let vault = InMemoryKeychainVault()
            let service = makeService(api: api, vault: vault)
            let wallet = makeWallet()
            let credentials = LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
            try credentials.saveAccount(PerpsStoredAccount(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex))
            try credentials.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))

            let before = (PerpsPlannerMapping.nowUnixMs() + header.signedShiftMs) / 1000
            let minted = await service.mintReadOnlyToken(wallet: wallet)
            await service.ensurePlusTier(
                wallet: wallet,
                trigger: .resolve,
                readOnlyToken: PerpsReadOnlyToken(mint: { await service.mintReadOnlyToken(wallet: wallet) })
            )
            let after = (PerpsPlannerMapping.nowUnixMs() + header.signedShiftMs) / 1000

            XCTAssertTrue(minted)
            let deadlines = await auths.values.map { Int64($0.split(separator: ":")[0]) }
            XCTAssertEqual(deadlines.count, 2)
            let lifetime = Int64(PerpsAccountService.readOnlyTokenDeadlineInterval)
            for deadline in deadlines {
                let deadline = try XCTUnwrap(deadline)
                XCTAssertTrue((before + lifetime - 1 ... after + lifetime + 1).contains(deadline), "Date \(header.skewMs) ms, deadline \(deadline)")
            }
        }
    }

    func testTheAccountBindingLivesFromTheSigningClock() async throws {
        for header in Self.dateHeaders {
            recordDateHeader(skewMs: header.skewMs)
            let requests = BindRequests()
            let vault = InMemoryKeychainVault()
            let wallet = makeWallet()
            let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
            let api = AccountStubAPI(account: .init(), onBindAccount: { request in
                await requests.record(request)
                throw AccountStubAPI.Unsupported()
            })
            let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)

            let before = (PerpsPlannerMapping.nowUnixMs() + header.signedShiftMs) / 1000
            _ = await service.bind(
                wallet: wallet,
                passcode: "1234",
                readOnlyToken: PerpsReadOnlyToken(mint: { false })
            )
            let after = (PerpsPlannerMapping.nowUnixMs() + header.signedShiftMs) / 1000

            let request = await requests.values.first
            let deadline = try XCTUnwrap(request?.deadline)
            let lifetime = Int64(PerpsAccountService.bindDeadlineInterval)
            XCTAssertTrue((before + lifetime - 1 ... after + lifetime + 1).contains(deadline), "Date \(header.skewMs) ms, deadline \(deadline)")
        }
    }

    func testTheIntegratorApprovalLivesFromTheSigningClock() async throws {
        for header in Self.dateHeaders {
            recordDateHeader(skewMs: header.skewMs)
            let sent = SentTransactions()
            let vault = InMemoryKeychainVault()
            let wallet = makeWallet()
            let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
            try await LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
                .keepTradingKey(cryptoWallet: CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.mnemonic))
            let integrator = Self.integrator
            let api = AccountStubAPI(
                account: .init(),
                integrator: integrator,
                nonce: 287,
                onSendTransactions: { _, transactions in
                    await sent.record(transactions)
                    throw AccountStubAPI.Unsupported()
                }
            )
            let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
            let lane = await service.submitLanes.lane(for: session)

            let before = PerpsPlannerMapping.nowUnixMs() + header.signedShiftMs
            let prepared = try await service.prepareIntegratorApproval(
                wallet: wallet,
                session: session,
                passcodeProvider: { "1234" }
            )
            let approval = try XCTUnwrap(prepared)
            _ = try? await lane.run {
                try await service.submitIntegratorApproval(approval, wallet: wallet, session: session, lane: lane)
            }
            let after = PerpsPlannerMapping.nowUnixMs() + header.signedShiftMs

            let first = await sent.values.first
            let transaction = try XCTUnwrap(first)
            let txInfo = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(transaction.tx_info.utf8)) as? [String: Any])
            let approvalExpiry = try XCTUnwrap((txInfo["ApprovalExpiry"] as? NSNumber)?.int64Value)
            let expiredAt = try XCTUnwrap((txInfo["ExpiredAt"] as? NSNumber)?.int64Value)
            let ttl = integrator.approval_ttl_ms
            XCTAssertTrue((before + ttl - 1000 ... after + ttl + 1000).contains(approvalExpiry), "Date \(header.skewMs) ms, approval expiry \(approvalExpiry)")
            let expiry = LighterConstants.shared.DefaultExpireTimeMillis
            XCTAssertTrue((before + expiry - 1000 ... after + expiry + 1000).contains(expiredAt), "Date \(header.skewMs) ms, expired at \(expiredAt)")
        }
    }

    func testAWithdrawalLivesFromTheSigningClock() async throws {
        for header in Self.dateHeaders {
            recordDateHeader(skewMs: header.skewMs)
            let vault = InMemoryKeychainVault()
            let wallet = makeWallet()
            let mnemonicAccess = try await savedMnemonicAccess(vault: vault, wallet: wallet)
            try LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
                .saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
            let api = AccountStubAPI(account: .init(), nonce: 12)
            let service = makeService(api: api, vault: vault, mnemonicAccess: mnemonicAccess)
            let lane = await service.submitLanes.lane(for: session)
            let transfer = PerpsWithdrawQuote(
                quoteId: "quote",
                expiresAt: Date().addingTimeInterval(60),
                executionId: "execution",
                destinationAssetId: PerpsFundingAssetId.usdcEthereum,
                recipient: "0x9858effd232b4033e47d90003d41ec34ecaeda94",
                budgetUnits: "1000000",
                outputUnits: "995000",
                minimumOutputUnits: "990000",
                toAccountIndex: 731_033,
                transferUnits: 1_000_000,
                feeUnits: 0,
                memo: Data(repeating: 0xAB, count: 32)
            )

            let before = PerpsPlannerMapping.nowUnixMs() + header.signedShiftMs
            let signed = try await lane.run {
                try await service.signWithdrawal(
                    wallet: wallet,
                    passcode: "1234",
                    session: session,
                    amountUnits: 1_000_000,
                    transfer: transfer,
                    lane: lane
                )
            }
            let after = PerpsPlannerMapping.nowUnixMs() + header.signedShiftMs

            let expiry = LighterConstants.shared.DefaultExpireTimeMillis
            XCTAssertTrue((before + expiry - 1000 ... after + expiry + 1000).contains(signed.expiry), "Date \(header.skewMs) ms, expiry \(signed.expiry)")
        }
    }

    func testAPendingTradeHoldsItsMarketUntilItsSigningClockExpiry() async throws {
        for (skewMs, blocks) in [(Int64(-50000), true), (-90000, false)] {
            recordDateHeader(skewMs: skewMs)
            let wallet = makeWallet()
            let api = AccountStubAPI(account: .init())
            let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
            let operationId = UUID().uuidString
            _ = try await journal.savePendingIfAbsentWithStatus(PerpsPendingTradingAction(
                operationId: operationId, walletId: wallet.id, marketId: 24, side: .long,
                payload: .open(limitPrice: nil),
                orderRefs: nil,
                signedSteps: [PerpsPendingSignedStep(
                    stepId: "open", attemptId: UUID().uuidString, nonce: 1,
                    transactionExpiryUnixMs: PerpsPlannerMapping.nowUnixMs() - 20000,
                    txType: 14, txInfo: "{}", txHash: "0xabc", state: .unknown
                )]
            ))
            let service = makeService(api: api, vault: InMemoryKeychainVault())
            let trading = PerpsTkTradingService(
                accountService: service,
                wallet: wallet,
                journal: journal,
                readOnlyToken: PerpsReadOnlyToken(mint: { false }),
                perpsAPI: api,
                markPriceProvider: { _ in nil },
                marketProvider: { _ in nil },
                freshReadDelayNanoseconds: 0
            )

            let blocked = await trading.marketsBlockedByPending()
            try await journal.removePending(operationId: operationId)

            XCTAssertEqual(blocked.contains(24), blocks, "Date \(skewMs) ms")
        }
    }
}

private extension PerpsSignedDeadlineTests {
    func recordDateHeader(skewMs: Int64) {
        PerpsServerClock.shared.record(serverDate: Date().addingTimeInterval(TimeInterval(skewMs) / 1000))
    }

    static var integrator: Components.Schemas.Integrator {
        .init(
            integrator_account_index: 281_474_976_487_764,
            integrator_taker_fee: 900,
            integrator_maker_fee: 900,
            max_perps_taker_fee: 1000,
            max_perps_maker_fee: 1000,
            max_spot_taker_fee: 0,
            max_spot_maker_fee: 0,
            approval_ttl_ms: 3_600_000
        )
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "perps-signed-deadline",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: WalletMetaData(label: "Perps", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "perps-signed-deadline",
                addresses: [.init(chain: .eth, address: "0x9858effd232b4033e47d90003d41ec34ecaeda94")],
                syncState: .synced
            ))
        )
    }

    func savedMnemonicAccess(vault: InMemoryKeychainVault, wallet: Wallet) async throws -> MnemonicAccess {
        let access = MnemonicAccess.inMemory(seed: "signed-deadline", keychainVault: vault)
        try await access.saveMnemonic(
            CoreMnemonic(mnemonicWords: Self.mnemonic.components(separatedBy: " "), type: .bip39),
            wallet: wallet,
            passcode: "1234"
        )
        return access
    }

    func makeService(
        api: PerpsAPI,
        vault: InMemoryKeychainVault,
        mnemonicAccess: MnemonicAccess? = nil
    ) -> PerpsAccountService {
        let client = CryptoKitClient(netModule: ModuleNetModule(netConfig: ModuleNetConfig(
            isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil
        )))
        return PerpsAccountService(
            mnemonicAccess: mnemonicAccess ?? .inMemory(seed: "unused", keychainVault: vault),
            keychainVault: vault,
            perpsAPI: api,
            submitLanes: PerpsSubmitLanes(api: api),
            bindSigner: PerpsAccountBindSigner(client: client),
            walletAuthTokenProvider: DeadlineUnusedWalletAuth(),
            chainKitClient: client,
            depositGate: OperationGate { [] }
        )
    }
}

private actor SignedAuths {
    private(set) var values: [String] = []
    func record(_ value: String) {
        values.append(value)
    }
}

private actor BindRequests {
    private(set) var values: [Components.Schemas.BindAccountRequest] = []
    func record(_ value: Components.Schemas.BindAccountRequest) {
        values.append(value)
    }
}

private actor SentTransactions {
    private(set) var values: [Components.Schemas.SignedTransaction] = []
    func record(_ transactions: [Components.Schemas.SignedTransaction]) {
        values.append(contentsOf: transactions)
    }
}

private struct DeadlineUnusedWalletAuth: WalletAuthTokenProviding {
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
