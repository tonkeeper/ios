import BigInt
@preconcurrency import ChainKit
import Foundation
import PerpsModels
import TKKeychain
import TKLogging
import TKPerpsAPI

@frozen public enum PerpsAccountStatus {
    case account(
        accountIndex: Int64,
        hasTradingKey: Bool? = nil,
        hasReadOnlyToken: Bool? = nil,
        availableBalance: String? = nil,
        collateral: String? = nil,
        equity: String? = nil
    )
    case unbound
    case noAccount(ethAddress: String)
    case unknown
    case unavailable(reason: String)
}

@frozen public enum PerpsAccountActivationOutcome {
    case active(accountIndex: Int64, apiKeyIndex: Int32, readOnlyTokenIssued: Bool)
    case noAccount(ethAddress: String)
    case failed(PerpsTradingError)
}

@frozen public enum PerpsAccountBindOutcome {
    case bound(accountIndex: Int64?)
    case addressMismatch(expected: String, bound: String)
    case takenByAnotherWallet(reason: String)
    case failed(PerpsTradingError)
}

struct PerpsSignedWithdrawal: Sendable {
    let nonce: Int64
    let expiry: Int64
    let txType: Int32
    let txInfo: String
    let txHash: String
}

private final class PerpsOwnerMessageSigner: NSObject, KotlinSuspendFunction1 {
    private let keySource: PerpetualAccountKeySource

    init(keySource: PerpetualAccountKeySource) {
        self.keySource = keySource
    }

    func invoke(p1: Any?, completionHandler: @escaping (Any?, Error?) -> Void) {
        guard let message = p1 as? String else {
            completionHandler(nil, PerpsTradingError.protocolFailure("invalid owner message"))
            return
        }
        keySource.signOwnerMessage(message: message) { signature, error in
            guard let signature, !signature.isEmpty else {
                completionHandler(nil, error ?? PerpsTradingError.protocolFailure("owner signature unavailable"))
                return
            }
            completionHandler(signature, nil)
        }
    }
}

struct PerpsAccountSession: Sendable {
    let accountIndex: Int64
    let apiKeyIndex: Int32
}

struct PerpsIntegratorApprovalKey: Codable, Equatable {
    let accountIndex: Int64
    let integratorAccountIndex: Int64
    let maxPerpsTakerFee: Int
    let maxPerpsMakerFee: Int
    let maxSpotTakerFee: Int
    let maxSpotMakerFee: Int
}

struct PerpsIntegratorApproval: Codable, Equatable {
    let key: PerpsIntegratorApprovalKey
    let expiry: Int64
}

struct PerpsPreparedIntegratorApproval {
    fileprivate let integrator: Components.Schemas.Integrator
    fileprivate let key: PerpsIntegratorApprovalKey
    fileprivate let cryptoWallet: MnemonicWallet
}

/// Holds no mutable state; `PerpsAPI` and the ChainKit clients are not marked `Sendable`.
public final class PerpsAccountService: @unchecked Sendable {
    private static let apiKeyIndex = LighterAuth.shared.API_KEY_INDEX
    private static let keyDerivationIndex: Int64 = 0

    private static let accountMediator: PerpetualAccountMediator =
        CompositePerpetualMediator().getAccountMediator(chain: .lighter)

    static let registrationConfirmationAttempts = 18

    static func registrationConfirmationDelayNanoseconds(attempt: Int) -> UInt64 {
        let base: UInt64 = 500_000_000
        let cap: UInt64 = 4_000_000_000
        return min(base << UInt64(min(max(attempt, 0), 3)), cap)
    }

    static let bindDeadlineInterval: TimeInterval = 300

    static let integratorApprovalRenewalWindowMs: Int64 = 86_400_000

    static let readOnlyTokenAttempts = 3
    static let readOnlyTokenRetryDelayNanoseconds: UInt64 = 2_000_000_000
    /// Lighter caps what it accepts and tk-perps caps it again at ten minutes; the
    /// authorization this app signs is shorter still.
    static let readOnlyTokenDeadlineInterval: TimeInterval = 300

    private static let lighterClient = LighterClient(
        crypto: LighterCryptoBridge(crypto: CoreLighterCrypto()),
        nowMillis: { KotlinLong(value: PerpsServerClock.shared.signingNowUnixMs()) }
    )

    static func tradingPublicKey(privateKey: Data) -> String {
        lighterClient.derivePublicKey(privateKeyHex: privateKey.map { String(format: "%02x", $0) }.joined())
    }

    private let mnemonicAccess: MnemonicAccess
    private let keychainVault: TKKeychainVault
    private let perpsAPI: PerpsAPI
    let submitLanes: PerpsSubmitLanes
    let integratorReads = PerpsIntegratorReads()
    private let bindSigner: PerpsAccountBindSigner
    private let walletAuthTokenProvider: WalletAuthTokenProviding
    private let chainKitClient: CryptoKitClient
    private let depositGate: OperationGate
    private let tierUpgrader: PerpsAccountTierUpgrader
    /// The swap's relayed fee methods, which pay a deposit's source fee in battery charges or a token.
    private let swapFeeMethods: () -> MultichainSwapFeeMethodResolver?
    private let walletAuthStore: WalletAuthKeychainStore
    private let securityConfig: PerpsSecurityConfigRepository?

    init(
        mnemonicAccess: MnemonicAccess,
        keychainVault: TKKeychainVault,
        perpsAPI: PerpsAPI,
        submitLanes: PerpsSubmitLanes,
        bindSigner: PerpsAccountBindSigner,
        walletAuthTokenProvider: WalletAuthTokenProviding,
        chainKitClient: CryptoKitClient,
        depositGate: OperationGate,
        tierUpgrader: PerpsAccountTierUpgrader = PerpsAccountTierUpgrader(),
        swapFeeMethods: @escaping () -> MultichainSwapFeeMethodResolver? = { nil },
        securityConfig: PerpsSecurityConfigRepository? = nil
    ) {
        self.mnemonicAccess = mnemonicAccess
        self.keychainVault = keychainVault
        self.walletAuthStore = WalletAuthKeychainStore(keychainVault: keychainVault)
        self.perpsAPI = perpsAPI
        self.submitLanes = submitLanes
        self.bindSigner = bindSigner
        self.walletAuthTokenProvider = walletAuthTokenProvider
        self.chainKitClient = chainKitClient
        self.depositGate = depositGate
        self.tierUpgrader = tierUpgrader
        self.swapFeeMethods = swapFeeMethods
        self.securityConfig = securityConfig
    }

    /// Lighter keeps the integrator fee schedule behind a wallet/account-level approval.
    /// The approval is signed by the account's L2 key and by the wallet's L1 owner key, and
    /// sent before the first order that uses a changed or expiring schedule. It is
    /// account-scoped, so one approval covers all markets and order kinds for this wallet.
    func prepareIntegratorApproval(
        wallet: Wallet,
        session: PerpsAccountSession,
        passcodeProvider: () async -> String?
    ) async throws -> PerpsPreparedIntegratorApproval? {
        let walletId = try walletId(wallet)
        let store = credentialsStore(wallet: wallet)
        let integrator = try await integrator(walletId: walletId)
        guard integrator.integrator_account_index != 0 else {
            store.clearIntegratorApproval()
            return nil
        }
        guard integrator.approval_ttl_ms > 0 else {
            throw PerpsTradingError.validation("integrator approval ttl must be positive")
        }

        let key = PerpsIntegratorApprovalKey(
            accountIndex: session.accountIndex,
            integratorAccountIndex: integrator.integrator_account_index,
            maxPerpsTakerFee: integrator.max_perps_taker_fee,
            maxPerpsMakerFee: integrator.max_perps_maker_fee,
            maxSpotTakerFee: integrator.max_spot_taker_fee,
            maxSpotMakerFee: integrator.max_spot_maker_fee
        )
        guard try !holdsIntegratorApproval(key, ttlMs: integrator.approval_ttl_ms, store: store) else {
            return nil
        }

        let logId = walletLogId(wallet)
        Log.perps.i("integrator approval required integrator=\(integrator.integrator_account_index) account=\(session.accountIndex) wallet=\(logId)")
        guard let passcode = await passcodeProvider() else {
            Log.perps.i("integrator approval: passcode canceled wallet=\(logId)")
            throw PerpsTradingError.activationCanceled
        }
        return try await PerpsPreparedIntegratorApproval(
            integrator: integrator,
            key: key,
            cryptoWallet: deriveCryptoWallet(wallet: wallet, passcode: passcode)
        )
    }

    func submitIntegratorApproval(
        _ approval: PerpsPreparedIntegratorApproval,
        wallet: Wallet,
        session: PerpsAccountSession,
        lane: PerpsSubmitLane
    ) async throws {
        let walletId = try walletId(wallet)
        let store = credentialsStore(wallet: wallet)
        let integrator = approval.integrator
        guard try !holdsIntegratorApproval(approval.key, ttlMs: integrator.approval_ttl_ms, store: store) else {
            return
        }
        guard let privateKeyHex = try await loadL2PrivateKeyHex(wallet: wallet), !privateKeyHex.isEmpty else {
            throw PerpsTradingError.credentialsRevoked
        }
        let now = PerpsServerClock.shared.signingNowUnixMs()
        let approvalExpiry = try checkedAdd(now, integrator.approval_ttl_ms, name: "integrator approval expiry")
        let expiredAt = try checkedAdd(now, LighterConstants.shared.DefaultExpireTimeMillis, name: "transaction expiry")
        // A refused transaction leaves the cursor past a nonce Lighter never used, and
        // unlike an order step the approval has no resign retry to recover from that.
        try await lane.resyncNonce(walletId: walletId)
        let nonce = try await lane.nextNonce(walletId: walletId)
        let txClient = Self.lighterClient.doNewTxClient(
            privateKeyHex: privateKeyHex,
            accountIndex: session.accountIndex,
            apiKeyIndex: session.apiKeyIndex,
            chainId: LighterConstants.shared.ChainId
        )
        let ownerSigner = PerpsOwnerMessageSigner(keySource: Self.accountMediator.keySource(wallet: approval.cryptoWallet))
        do {
            let request = try LighterApproveIntegratorTxReq(
                integratorAccountIndex: integrator.integrator_account_index,
                maxPerpsTakerFee: int32(integrator.max_perps_taker_fee, name: "max perps taker fee"),
                maxPerpsMakerFee: int32(integrator.max_perps_maker_fee, name: "max perps maker fee"),
                maxSpotTakerFee: int32(integrator.max_spot_taker_fee, name: "max spot taker fee"),
                maxSpotMakerFee: int32(integrator.max_spot_maker_fee, name: "max spot maker fee"),
                approvalExpiry: approvalExpiry
            )
            let transaction: L2ApproveIntegratorTxInfo = try await bridgeKotlin { completion in
                txClient.getApproveIntegratorTransaction(
                    req: request,
                    ops: LighterTransactOpts(
                        fromAccountIndex: nil,
                        apiKeyIndex: nil,
                        expiredAt: expiredAt,
                        nonce: KotlinLong(value: nonce),
                        attributes: nil,
                        dryRun: false
                    ),
                    l1Signer: ownerSigner,
                    completionHandler: completion
                )
            }
            try await lane.send(
                walletId: walletId,
                txType: transaction.txType,
                txInfo: transaction.getTxInfo(),
                txHash: transaction.getTxHash(),
                nonce: nonce
            )
        } catch {
            try? await lane.resyncNonce(walletId: walletId)
            throw error
        }
        Log.perps.i("integrator approval sent integrator=\(integrator.integrator_account_index) account=\(session.accountIndex) expiry=\(approvalExpiry) wallet=\(walletLogId(wallet))")
        do {
            try store.saveIntegratorApproval(PerpsIntegratorApproval(key: approval.key, expiry: approvalExpiry))
        } catch {
            Log.perps.w("integrator approval not recorded wallet=\(walletLogId(wallet))", error: error)
        }
    }

    /// Lighter answered that the account holds no approval, whatever this device recorded.
    func forgetIntegratorApproval(wallet: Wallet) {
        credentialsStore(wallet: wallet).clearIntegratorApproval()
    }

    func bind(wallet: Wallet, passcode: String, readOnlyToken: PerpsReadOnlyToken) async -> PerpsAccountBindOutcome {
        let logId = walletLogId(wallet)
        Log.perps.i("bind: start wallet=\(logId)")
        let cryptoWallet: MnemonicWallet
        let walletId: String
        do {
            walletId = try self.walletId(wallet)
            cryptoWallet = try await deriveCryptoWallet(wallet: wallet, passcode: passcode)
        } catch let error as PerpsTradingError {
            return .failed(error)
        } catch {
            return .failed(PerpsTradingErrorMapper.map(error))
        }

        let binding: PerpsAccountBinding
        do {
            binding = try await bindSigner.makeBinding(
                wallet: cryptoWallet,
                walletId: walletId,
                deadline: PerpsServerClock.shared.signingNowUnixMs() / 1000 + Int64(Self.bindDeadlineInterval)
            )
            Log.perps.i("bind: signed wallet=\(logId) l1=\(binding.l1Address)")
        } catch {
            Log.perps.w("bind: signing failed wallet=\(logId)", error: error)
            return .failed(.validation("failed to sign account binding: \(error)"))
        }

        let request = Components.Schemas.BindAccountRequest(
            deadline: binding.deadline,
            signature: binding.signature,
            proof: binding.proof
        )
        do {
            let account = try await perpsAPI.bindAccount(walletId: walletId, request: request)
            guard let bound = account.l1_address?.lowercased(), bound == binding.l1Address else {
                Log.perps.w("bind: address mismatch wallet=\(logId) signed=\(binding.l1Address) bound=\(account.l1_address ?? "nil")")
                return .addressMismatch(expected: binding.l1Address, bound: account.l1_address ?? "")
            }
            Log.perps.i("bind: bound wallet=\(logId) account=\(String(describing: account.account_index)) status=\(account.status?.rawValue ?? "nil")")
            guard let accountIndex = account.account_index.map(Int64.init) else {
                await keepTradingKey(wallet: wallet, cryptoWallet: cryptoWallet)
                return .bound(accountIndex: nil)
            }
            var readOnlyTokenIssued = false
            if account.has_l2_key != true {
                readOnlyTokenIssued = await registerTradingKey(
                    wallet: wallet,
                    cryptoWallet: cryptoWallet,
                    readOnlyToken: readOnlyToken,
                    logId: logId
                )
            }
            if !readOnlyTokenIssued {
                await ensureReadOnlyToken(wallet: wallet, cryptoWallet: cryptoWallet, readOnlyToken: readOnlyToken)
            }
            return .bound(accountIndex: accountIndex)
        } catch let error as PerpsAPIError {
            if case let .badStatus(failure) = error, failure.httpStatus == 409 {
                Log.perps.w("bind: conflict wallet=\(logId) reason=\(failure.reason ?? failure.code ?? "unknown")")
                return .takenByAnotherWallet(reason: failure.reason ?? failure.code ?? "conflict")
            }
            Log.perps.w("bind: failed wallet=\(logId)", error: error)
            return .failed(PerpsTradingErrorMapper.map(error))
        } catch {
            Log.perps.w("bind: failed wallet=\(logId)", error: error)
            return .failed(PerpsTradingErrorMapper.map(error))
        }
    }

    public func holdsKeptTradingKey(wallet: Wallet) -> Bool {
        (try? credentialsStore(wallet: wallet).loadL2PrivateKey())?.isEmpty == false
    }

    public func keepTradingKey(wallet: Wallet, passcode: String) async -> Bool {
        guard let cryptoWallet = try? await deriveCryptoWallet(wallet: wallet, passcode: passcode) else { return false }
        await keepTradingKey(wallet: wallet, cryptoWallet: cryptoWallet)
        return holdsKeptTradingKey(wallet: wallet)
    }

    func activate(
        wallet: Wallet,
        passcode: String,
        readOnlyToken: PerpsReadOnlyToken
    ) async -> PerpsAccountActivationOutcome {
        let cryptoWallet: MnemonicWallet
        do {
            cryptoWallet = try await deriveCryptoWallet(wallet: wallet, passcode: passcode)
        } catch let error as PerpsTradingError {
            return .failed(error)
        } catch {
            return .failed(PerpsTradingErrorMapper.map(error))
        }
        return await activate(wallet: wallet, cryptoWallet: cryptoWallet, readOnlyToken: readOnlyToken)
    }

    /// Activation without the passcode, for an account a first deposit created with the key kept
    /// before it (`keepTradingKey`): once the account holds that key in this wallet's slot, only
    /// the account is left to record. `false` leaves activation to the passcode.
    func adoptRegisteredTradingKey(wallet: Wallet, readOnlyToken: PerpsReadOnlyToken) async -> Bool {
        let logId = walletLogId(wallet)
        let store = credentialsStore(wallet: wallet)
        do {
            guard try store.loadAccount() == nil,
                  let key = try store.loadL2PrivateKey(), !key.isEmpty
            else { return false }
            let account = try await perpsAPI.account(walletId: walletId(wallet))
            guard let accountIndex = account.account_index,
                  PerpsTkAccountDelegate.holdsKey(
                      account,
                      apiKeyIndex: Int(Self.apiKeyIndex),
                      publicKey: Self.tradingPublicKey(privateKey: key)
                  ) == true
            else { return false }
            guard PerpsTkAccountDelegate.isBound(account, to: wallet.multichainAddress(for: .eth)) else {
                Log.perps.w("activation: account bound to another address account=\(accountIndex) l1=\(account.l1_address ?? "nil") wallet=\(logId)")
                return false
            }
            try store.saveAccount(
                PerpsStoredAccount(
                    accountIndex: Int64(accountIndex),
                    apiKeyIndex: Self.apiKeyIndex,
                    keyDerivationIndex: Self.keyDerivationIndex
                )
            )
            Log.perps.i("activation: adopted the key the deposit registered account=\(accountIndex) wallet=\(logId)")
            // As `activate` does; `keepTradingKey` kept the wallet auth key the mint signs with.
            await readOnlyToken.issue()
            Task { await self.ensurePlusTier(wallet: wallet, trigger: .activation, readOnlyToken: readOnlyToken) }
            return true
        } catch {
            Log.perps.w("activation: registered key not adopted wallet=\(logId)", error: error)
            return false
        }
    }

    private func activate(
        wallet: Wallet,
        cryptoWallet: MnemonicWallet,
        readOnlyToken: PerpsReadOnlyToken
    ) async -> PerpsAccountActivationOutcome {
        let logId = walletLogId(wallet)
        Log.perps.i("activation: start wallet=\(logId)")
        do {
            let walletId = try walletId(wallet)
            let mediator = Self.accountMediator
            let keySource = mediator.keySource(wallet: cryptoWallet)
            let delegate = try await PerpsTkAccountDelegate(
                walletId: walletId,
                api: perpsAPI,
                apiKeyIndex: Int(Self.apiKeyIndex),
                expectedPublicKey: tradingPublicKey(keySource: keySource),
                ownerAddress: cryptoWallet.getAddress(chain: ChainEthereumMainnet.shared).display
            )
            let state: PerpsAccountState = try await bridgeKotlin { completion in
                mediator.activate(
                    keySource: keySource,
                    delegate: delegate,
                    nowUnixMs: PerpsServerClock.shared.signingNowUnixMs(),
                    completionHandler: completion
                )
            }
            Log.perps.i("activation: mediator finished account=\(String(describing: state.accountIndex)) hasL2Key=\(String(describing: state.hasL2Key)) status=\(state.status ?? "nil") wallet=\(logId)")
            guard let accountIndex = state.accountIndex else {
                await keepTradingKey(wallet: wallet, cryptoWallet: cryptoWallet)
                return .noAccount(ethAddress: state.l1Address ?? cryptoWallet.getAddress(chain: ChainEthereumMainnet.shared).display)
            }
            guard state.hasL2Key == true else {
                return .failed(.protocolFailure("account key registration did not confirm"))
            }
            try await persistActivationCredentials(
                wallet: wallet,
                keySource: keySource,
                accountIndex: Int64(truncating: accountIndex)
            )
            Log.perps.i("activation: credentials persisted account=\(accountIndex) wallet=\(logId)")
            let readOnlyTokenIssued = await ensureReadOnlyToken(
                wallet: wallet,
                cryptoWallet: cryptoWallet,
                readOnlyToken: readOnlyToken
            )
            // tk-perps reads the tier with the read-only token, so only once there is one.
            Task { await self.ensurePlusTier(wallet: wallet, trigger: .activation, readOnlyToken: readOnlyToken) }
            return .active(
                accountIndex: Int64(truncating: accountIndex),
                apiKeyIndex: Self.apiKeyIndex,
                readOnlyTokenIssued: readOnlyTokenIssued
            )
        } catch {
            Log.perps.w("activation: failed wallet=\(logId)", error: error)
            return .failed(PerpsTradingErrorMapper.map(error))
        }
    }

    @discardableResult
    func ensureReadOnlyToken(
        wallet: Wallet,
        cryptoWallet: MnemonicWallet,
        readOnlyToken: PerpsReadOnlyToken
    ) async -> Bool {
        await persistWalletAuthKeyIfMissing(wallet: wallet, cryptoWallet: cryptoWallet)
        return await readOnlyToken.issue()
    }

    func mintReadOnlyToken(wallet: Wallet) async -> Bool {
        let logId = walletLogId(wallet)
        for attempt in 1 ... Self.readOnlyTokenAttempts {
            do {
                let walletId = try walletId(wallet)
                guard let account = try credentialsStore(wallet: wallet).loadAccount(),
                      let privateKeyHex = try await loadL2PrivateKeyHex(wallet: wallet),
                      !privateKeyHex.isEmpty
                else {
                    Log.perps.i("ro-token: no trading key yet wallet=\(logId)")
                    return false
                }
                Log.perps.i("ro-token: issuing wallet=\(logId)")
                let lighterAuth = Self.lighterClient.authToken(
                    privateKeyHex: privateKeyHex,
                    accountIndex: account.accountIndex,
                    apiKeyIndex: account.apiKeyIndex,
                    deadlineUnixSeconds: PerpsServerClock.shared.signingNowUnixMs() / 1000 + Int64(Self.readOnlyTokenDeadlineInterval)
                )
                let issued = try await perpsAPI.issueReadOnlyToken(walletId: walletId, lighterAuth: lighterAuth)
                Log.perps.i("ro-token: issued account=\(issued.account_index) expires=\(issued.expires_at) wallet=\(logId)")
                return true
            } catch {
                let mapped = PerpsTradingErrorMapper.map(error)
                guard attempt < Self.readOnlyTokenAttempts, PerpsExecutionRelay.isAmbiguous(mapped) else {
                    Log.perps.w("ro-token: issue failed wallet=\(logId)", error: error)
                    return false
                }
                Log.perps.w("ro-token: retrying after \(mapped) wallet=\(logId)")
                try? await Task.sleep(nanoseconds: Self.readOnlyTokenRetryDelayNanoseconds)
            }
        }
        return false
    }

    func persistWalletAuthKeyIfMissing(wallet: Wallet, cryptoWallet: MnemonicWallet) async {
        guard let walletId = try? walletId(wallet) else { return }
        do {
            guard try walletAuthStore.loadAppKey(walletId: walletId) == nil else { return }
        } catch {
            Log.perps.w("ro-token: wallet auth key unreadable wallet=\(walletLogId(wallet))", error: error)
            return
        }
        let appKey = bindSigner.walletAuthKey(wallet: cryptoWallet)
        await walletAuthTokenProvider.persistAppKey(appKey, walletId: walletId)
    }

    func verifiedSecurityConfig() async -> PerpsSecurityConfig? {
        await securityConfig?.verified()
    }

    func integrator(walletId: String) async throws -> Components.Schemas.Integrator {
        try await integratorReads.value(walletId: walletId) { [perpsAPI] in
            try await perpsAPI.integrator(walletId: walletId)
        }
    }

    func refreshIntegrator(walletId: String) {
        integratorReads.refresh(walletId: walletId) { [perpsAPI] in
            try await perpsAPI.integrator(walletId: walletId)
        }
    }

    /// Runs after activation, on every resolve of an activated account — so an account activated
    /// before this existed is caught up the next time the perps section opens — and before a trade.
    func ensurePlusTier(
        wallet: Wallet,
        trigger: PerpsAccountTierUpgrader.Trigger,
        readOnlyToken: PerpsReadOnlyToken
    ) async {
        guard let account = try? credentialsStore(wallet: wallet).loadAccount(),
              let walletId = try? walletId(wallet)
        else {
            Log.perps.d("tier: no stored account trigger=\(trigger.rawValue) wallet=\(walletLogId(wallet))")
            return
        }
        await tierUpgrader.ensurePlus(
            accountIndex: account.accountIndex,
            trigger: trigger,
            readTier: { [self] in
                // Runs alongside the resolve's own token repair, so it cannot count on a usable token.
                let tier = try await PerpsAPIError.reissuingReadOnlyToken({ await readOnlyToken.issue() }) {
                    try await perpsAPI.accountTier(walletId: walletId)
                }
                Log.perps.d("tier: read id=\(tier.id) name=\(tier.name) account=\(account.accountIndex)")
                return tier.name
            },
            changeTier: { [self] newTier in
                guard let privateKeyHex = try await loadL2PrivateKeyHex(wallet: wallet), !privateKeyHex.isEmpty else {
                    throw PerpsTradingError.credentialsRevoked
                }
                let lighterAuth = Self.lighterClient.authToken(
                    privateKeyHex: privateKeyHex,
                    accountIndex: account.accountIndex,
                    apiKeyIndex: account.apiKeyIndex,
                    deadlineUnixSeconds: PerpsServerClock.shared.signingNowUnixMs() / 1000 + Int64(Self.readOnlyTokenDeadlineInterval)
                )
                try await perpsAPI.changeAccountTier(walletId: walletId, lighterAuth: lighterAuth, newTier: newTier)
            }
        )
    }

    func tradingSession(wallet: Wallet) async throws -> PerpsAccountSession? {
        guard let account = try credentialsStore(wallet: wallet).loadAccount(),
              account.keyDerivationIndex == Self.keyDerivationIndex
        else { return nil }
        guard let key = try await loadL2PrivateKeyHex(wallet: wallet), !key.isEmpty else { return nil }
        return PerpsAccountSession(
            accountIndex: account.accountIndex,
            apiKeyIndex: account.apiKeyIndex
        )
    }

    func loadL2PrivateKeyHex(wallet: Wallet) async throws -> String? {
        guard let bytes = try credentialsStore(wallet: wallet).loadL2PrivateKey() else { return nil }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    func signWithdrawal(
        wallet: Wallet,
        passcode: String,
        session: PerpsAccountSession,
        amountUnits: Int64,
        transfer: PerpsWithdrawQuote,
        lane: PerpsSubmitLane
    ) async throws -> PerpsSignedWithdrawal {
        let walletId = try walletId(wallet)
        guard let privateKeyHex = try await loadL2PrivateKeyHex(wallet: wallet), !privateKeyHex.isEmpty else {
            throw PerpsTradingError.credentialsRevoked
        }
        // Everything that can refuse runs before a nonce is taken: one taken and never sent
        // leaves a gap the venue rejects the next transaction of this key for.
        guard transfer.expiresAt > Date(),
              let budget = BigUInt(transfer.budgetUnits, radix: 10), budget >= BigUInt(amountUnits),
              LighterConstants.shared.AssetRouteTypePerps == 0
        else {
            throw PerpsWithdrawQuoteError.expired
        }
        let cryptoWallet = try await deriveCryptoWallet(wallet: wallet, passcode: passcode)
        guard transfer.expiresAt > Date() else { throw PerpsWithdrawQuoteError.expired }
        let ownerSigner = PerpsOwnerMessageSigner(keySource: Self.accountMediator.keySource(wallet: cryptoWallet))
        let nonce = try await lane.nextNonce(walletId: walletId)
        do {
            let nowMs = PerpsServerClock.shared.signingNowUnixMs()
            let expiry = min(nowMs + LighterConstants.shared.DefaultExpireTimeMillis, LighterConstants.shared.MaxTimestamp)
            let client = Self.lighterClient.doNewTxClient(
                privateKeyHex: privateKeyHex,
                accountIndex: session.accountIndex,
                apiKeyIndex: session.apiKeyIndex,
                chainId: LighterConstants.shared.ChainId
            )
            let options = LighterTransactOpts(
                fromAccountIndex: nil,
                apiKeyIndex: nil,
                expiredAt: expiry,
                nonce: KotlinLong(value: nonce),
                attributes: nil,
                dryRun: false
            )
            let request = LighterTransferTxReq(
                toAccountIndex: transfer.toAccountIndex,
                assetIndex: 3,
                fromRouteType: LighterConstants.shared.AssetRouteTypePerps,
                toRouteType: LighterConstants.shared.AssetRouteTypePerps,
                amount: transfer.transferUnits,
                usdcFee: transfer.feeUnits,
                memo: transfer.memo.asKotlinByteArray
            )
            let transaction: L2TransferTxInfo = try await bridgeKotlin { completion in
                client.getTransferTransaction(req: request, ops: options, l1Signer: ownerSigner, completionHandler: completion)
            }
            guard transaction.txType == 12,
                  transaction.fromAccountIndex == session.accountIndex,
                  transaction.toAccountIndex == transfer.toAccountIndex,
                  transaction.assetIndex == 3,
                  transaction.apiKeyIndex == session.apiKeyIndex,
                  transaction.nonce == nonce,
                  transaction.expiredAt == expiry,
                  transaction.fromRouteType == 0,
                  transaction.toRouteType == 0,
                  transaction.amount == transfer.transferUnits,
                  transaction.usdcFee == transfer.feeUnits,
                  transaction.memo.asData == transfer.memo,
                  !transaction.l1Sig.isEmpty
            else {
                throw PerpsTradingError.protocolFailure("signed transfer differs from the checked quote")
            }
            return PerpsSignedWithdrawal(
                nonce: nonce,
                expiry: expiry,
                txType: transaction.txType,
                txInfo: transaction.getTxInfo(),
                txHash: transaction.getTxHash()
            )
        } catch {
            try? await lane.resyncNonce(walletId: walletId)
            throw error
        }
    }

    func ensureDepositBinding(wallet: Wallet, passcode: String, readOnlyToken: PerpsReadOnlyToken) async throws {
        let account = try await perpsAPI.account(walletId: walletId(wallet))
        if let bound = account.l1_address {
            guard let expected = wallet.multichainAddress(for: .eth), PerpsFundingAssetId.sameAddress(bound, expected) else {
                throw PerpsTradingError.validation("deposit account address does not match the wallet")
            }
            return
        }
        try Task.checkCancellation()
        switch await bind(wallet: wallet, passcode: passcode, readOnlyToken: readOnlyToken) {
        case .bound:
            try Task.checkCancellation()
        case let .failed(error):
            throw error
        case .addressMismatch, .takenByAnotherWallet:
            throw PerpsTradingError.validation("deposit account binding refused")
        }
    }

    /// A deposit owner for this wallet. Not cached here, where it would outlive the wallet:
    /// `PerpsWalletScope` keeps the one instance whose actor serializes that wallet's payments.
    func depositService(
        wallet: Wallet,
        journal: PerpsPendingJournal,
        recovery: PerpsFundingRecovery,
        readOnlyToken: PerpsReadOnlyToken
    ) -> PerpsDepositService? {
        guard let state = wallet.multichainWalletState else { return nil }
        let walletId = state.walletId
        return PerpsDepositService(
            walletId: walletId,
            walletIdentity: wallet.id,
            environment: PerpsEnvironment.venue,
            journal: journal,
            api: perpsAPI,
            delivery: PerpsChainKitDepositDelivery(client: chainKitClient, mnemonicAccess: mnemonicAccess, wallet: wallet),
            gate: depositGate,
            recovery: recovery,
            keyRegistration: { [credentialsStore = credentialsStore(wallet: wallet)] in
                guard let key = try? credentialsStore.loadL2PrivateKey(), !key.isEmpty else { return nil }
                return PerpsKeyRegistration(apiKeyIndex: Int(Self.apiKeyIndex), publicKey: Self.tradingPublicKey(privateKey: key))
            },
            securityConfig: { [securityConfig] in await securityConfig?.verified() },
            downloadedSecurityConfig: { [securityConfig] in await securityConfig?.verifiedAfterDownload() },
            ensureBinding: { [self] passcode in
                try await ensureDepositBinding(wallet: wallet, passcode: passcode, readOnlyToken: readOnlyToken)
            },
            relaying: swapFeeMethods().map {
                PerpsDepositRelaying(swapWallet: MultichainSwapWallet(wallet: wallet, registeredState: state), resolver: $0)
            }
        )
    }

    func withdrawService(
        wallet: Wallet,
        journal: PerpsPendingJournal,
        recovery: PerpsFundingRecovery,
        readOnlyToken: PerpsReadOnlyToken,
        transferFeeUnits: @escaping @Sendable (_ accountIndex: Int64, _ toAccountIndex: Int64) async -> Int64? = PerpsWithdrawService.lighterTransferFeeUnits,
        securityConfig: (@Sendable () async -> PerpsSecurityConfig?)? = nil
    ) -> PerpsWithdrawService? {
        guard let walletId = wallet.multichainWalletState?.walletId else { return nil }
        let verifiedConfig = securityConfig ?? { [repository = self.securityConfig] in await repository?.verified() }
        return PerpsWithdrawService(
            wallet: wallet,
            walletId: walletId,
            environment: PerpsEnvironment.venue,
            journal: journal,
            api: perpsAPI,
            accountService: self,
            recovery: recovery,
            readOnlyToken: readOnlyToken,
            transferFeeUnits: transferFeeUnits,
            securityConfig: verifiedConfig
        )
    }

    func fundingRecovery(
        wallet: Wallet,
        journal: PerpsPendingJournal,
        awaitChange: (@Sendable (UInt64) async -> Bool)? = nil
    ) -> PerpsFundingRecovery {
        PerpsFundingRecovery(
            walletId: wallet.multichainWalletState?.walletId,
            walletIdentity: wallet.id,
            environment: PerpsEnvironment.venue,
            journal: journal,
            api: perpsAPI,
            submitLanes: submitLanes,
            delivery: PerpsChainKitDepositDelivery(client: chainKitClient, mnemonicAccess: mnemonicAccess, wallet: wallet),
            awaitChange: awaitChange
        )
    }

    public func clearCredentials(wallet: Wallet) {
        credentialsStore(wallet: wallet).clear()
    }
}

final class PerpsTkAccountDelegate: NSObject, PerpsAccountDelegate {
    private let walletId: String
    private let api: PerpsAPI
    private let apiKeyIndex: Int
    private let expectedPublicKey: String
    private let ownerAddress: String
    @Atomic private var hadL2KeyBeforeSubmit: Bool?

    init(walletId: String, api: PerpsAPI, apiKeyIndex: Int, expectedPublicKey: String, ownerAddress: String) {
        self.walletId = walletId
        self.api = api
        self.apiKeyIndex = apiKeyIndex
        self.expectedPublicKey = Self.normalizedHash(expectedPublicKey)
        self.ownerAddress = ownerAddress
    }

    func accountState(completionHandler: @escaping (PerpsAccountState?, Error?) -> Void) {
        Log.perps.i("activation: account state request wallet=\(walletLogId(walletId))")
        Task {
            do {
                let account = try await api.account(walletId: walletId)
                if account.account_index != nil || account.l1_address != nil {
                    try requireOwned(account)
                }
                hadL2KeyBeforeSubmit = account.has_l2_key
                let state = Self.state(of: account, hasL2Key: holdsOurKey(account) ?? account.has_l2_key)
                Log.perps.i("activation: account state response account=\(String(describing: state.accountIndex)) hasL2Key=\(String(describing: state.hasL2Key)) status=\(state.status ?? "nil") l1=\(state.l1Address ?? "nil")")
                completionHandler(state, nil)
            } catch {
                Log.perps.w("activation: account state failed wallet=\(walletLogId(walletId))", error: error)
                completionHandler(nil, error)
            }
        }
    }

    func nextNonce(
        accountIndex: Int64,
        apiKeyIndex: Int32,
        completionHandler: @escaping (KotlinLong?, Error?) -> Void
    ) {
        Log.perps.i("activation: nonce request account=\(accountIndex) apiKey=\(apiKeyIndex)")
        Task {
            do {
                let response = try await api.nextNonce(walletId: walletId, apiKeyIndex: Int(apiKeyIndex))
                guard response.account_index == accountIndex else {
                    throw PerpsTradingError.protocolFailure("nonce account does not match activation account")
                }
                Log.perps.i("activation: nonce response account=\(accountIndex) nonce=\(response.nonce)")
                completionHandler(KotlinLong(value: response.nonce), nil)
            } catch {
                Log.perps.w("activation: nonce failed account=\(accountIndex)", error: error)
                completionHandler(nil, error)
            }
        }
    }

    func submitRegistration(
        registration: PerpsAccountRegistration,
        completionHandler: @escaping (PerpsAccountSubmissionOutcome?, Error?) -> Void
    ) {
        Log.perps.i("activation: registration submit start account=\(registration.accountIndex) apiKey=\(registration.apiKeyIndex) txType=\(registration.txType)")
        Task {
            do {
                let response = try await api.sendTransactions(
                    walletId: walletId,
                    operationId: nil,
                    transactions: [.init(tx_type: Int32(registration.txType), tx_info: registration.txInfo)]
                )
                guard response.transactions.count == 1,
                      response.transactions[0].tx_type == Int32(registration.txType),
                      Self.normalizedHash(response.transactions[0].tx_hash) == Self.normalizedHash(registration.txHash)
                else {
                    Log.perps.w("activation: registration response mismatch account=\(registration.accountIndex) txType=\(registration.txType)")
                    completionHandler(.protocolfailure, nil)
                    return
                }
                Log.perps.i("activation: registration accepted account=\(registration.accountIndex) txType=\(registration.txType)")
                completionHandler(.accepted, nil)
            } catch let error as PerpsAPIError where error.isResignRequired {
                Log.perps.i("activation: registration resign required account=\(registration.accountIndex) txType=\(registration.txType)")
                completionHandler(.resignrequired, nil)
            } catch {
                Log.perps.w("activation: registration submit failed account=\(registration.accountIndex)", error: error)
                completionHandler(nil, error)
            }
        }
    }

    func confirmRegistration(
        registration: PerpsAccountRegistration,
        completionHandler: @escaping (PerpsAccountState?, Error?) -> Void
    ) {
        Log.perps.i("activation: confirmation start account=\(registration.accountIndex) txType=\(registration.txType)")
        Task {
            do {
                for attempt in 0 ..< PerpsAccountService.registrationConfirmationAttempts {
                    let account = try await api.account(walletId: walletId)
                    guard account.account_index.map(Int64.init) == registration.accountIndex else {
                        Log.perps.w("activation: confirmation for another account signed=\(registration.accountIndex) answered=\(String(describing: account.account_index))")
                        throw PerpsTradingError.protocolFailure("account key registration was confirmed for another account")
                    }
                    try requireOwned(account)
                    if isRegistered(account) {
                        Log.perps.i("activation: confirmation success account=\(registration.accountIndex) attempt=\(attempt + 1)")
                        completionHandler(Self.state(of: account, hasL2Key: true), nil)
                        return
                    }
                    if attempt == 0 || attempt == 9 {
                        Log.perps.i("activation: confirmation pending account=\(registration.accountIndex) attempt=\(attempt + 1)")
                    }
                    try await Task.sleep(
                        nanoseconds: PerpsAccountService.registrationConfirmationDelayNanoseconds(attempt: attempt)
                    )
                }
                Log.perps.w("activation: confirmation timeout account=\(registration.accountIndex)")
                completionHandler(nil, PerpsTradingError.protocolFailure("account key registration confirmation timed out"))
            } catch {
                Log.perps.w("activation: confirmation failed account=\(registration.accountIndex)", error: error)
                completionHandler(nil, error)
            }
        }
    }

    private static func normalizedHash(_ hash: String) -> String {
        let value = hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
    }

    static func isBound(_ account: Components.Schemas.Account, to ownerAddress: String?) -> Bool {
        guard let bound = account.l1_address, let ownerAddress else { return false }
        return PerpsFundingAssetId.sameAddress(bound, ownerAddress)
    }

    private func requireOwned(_ account: Components.Schemas.Account) throws {
        guard Self.isBound(account, to: ownerAddress) else {
            Log.perps.w("activation: account bound to another address account=\(String(describing: account.account_index)) l1=\(account.l1_address ?? "nil") wallet=\(walletLogId(walletId))")
            throw PerpsTradingError.protocolFailure("account is bound to another address")
        }
    }

    private func holdsOurKey(_ account: Components.Schemas.Account) -> Bool? {
        Self.holdsKey(account, apiKeyIndex: apiKeyIndex, publicKey: expectedPublicKey)
    }

    /// `nil` when the account does not list its keys.
    static func holdsKey(_ account: Components.Schemas.Account, apiKeyIndex: Int, publicKey: String) -> Bool? {
        account.api_keys?.contains {
            $0.api_key_index == apiKeyIndex && normalizedHash($0.public_key) == normalizedHash(publicKey)
        }
    }

    private func isRegistered(_ account: Components.Schemas.Account) -> Bool {
        let ourKey = holdsOurKey(account)
        return ourKey == true
            || (ourKey == nil && account.has_l2_key == true)
            || (account.has_l2_key == true && hadL2KeyBeforeSubmit == false)
    }

    private static func state(of account: Components.Schemas.Account, hasL2Key: Bool?) -> PerpsAccountState {
        PerpsAccountState(
            accountIndex: account.account_index.map { KotlinLong(value: Int64($0)) },
            l1Address: account.l1_address,
            status: account.status?.rawValue,
            hasL2Key: hasL2Key.map { KotlinBoolean(value: $0) },
            collateral: account.collateral,
            availableBalance: account.available_balance
        )
    }
}

func walletLogId(_ walletId: String) -> String {
    walletId.count <= 6 ? "…" : "…\(walletId.suffix(6))"
}

private func walletLogId(_ wallet: Wallet) -> String {
    walletLogId(wallet.id)
}

private extension PerpsAccountService {
    /// Trading needs a key the service cannot register for us: it never sees the trading key and
    /// only relays what the device signed. Binding is the one unlock a wallet is guaranteed to
    /// go through, so the key is registered there rather than inside the first confirmed trade.
    /// A failure is not a failed binding — the trading path still activates on demand.
    func registerTradingKey(
        wallet: Wallet,
        cryptoWallet: MnemonicWallet,
        readOnlyToken: PerpsReadOnlyToken,
        logId: String
    ) async -> Bool {
        switch await activate(wallet: wallet, cryptoWallet: cryptoWallet, readOnlyToken: readOnlyToken) {
        case let .active(accountIndex, apiKeyIndex, readOnlyTokenIssued):
            Log.perps.i("bind: trading key registered account=\(accountIndex) apiKey=\(apiKeyIndex) wallet=\(logId)")
            return readOnlyTokenIssued
        case .noAccount:
            Log.perps.i("bind: trading key deferred — no account yet wallet=\(logId)")
        case let .failed(error):
            Log.perps.w("bind: trading key registration failed \(error) wallet=\(logId)")
        }
        return false
    }

    func deriveCryptoWallet(wallet: Wallet, passcode: String) async throws -> MnemonicWallet {
        let logId = walletLogId(wallet)
        let phrase: String
        do {
            let mnemonic = try await mnemonicAccess.getMnemonic(wallet: wallet, passcode: passcode)
            Log.perps.i("mnemonic loaded type=\(mnemonic.type) wallet=\(logId)")
            switch mnemonic.type {
            case .bip39:
                break
            case .bip39soft:
                throw PerpsTradingError.validation("recovery phrase checksum invalid")
            case .ton, .unknown:
                throw PerpsTradingError.validation("wallet mnemonic is not BIP39 — perps unsupported for this wallet")
            }
            phrase = mnemonic.mnemonicWords.joined(separator: " ")
        } catch let error as PerpsTradingError {
            throw error
        } catch {
            Log.perps.w("mnemonic load failed wallet=\(logId)", error: error)
            throw PerpsTradingError.validation("failed to read mnemonic: \(error)")
        }
        do {
            let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: phrase)
            Log.perps.i("wallet derivation ready wallet=\(logId)")
            return cryptoWallet
        } catch {
            Log.perps.w("wallet derivation failed wallet=\(logId)", error: error)
            throw PerpsTradingError.validation("failed to derive wallet: \(error)")
        }
    }

    func walletId(_ wallet: Wallet) throws -> String {
        guard let id = wallet.multichainWalletState?.walletId, !id.isEmpty else {
            throw PerpsAccountReadError.missingWalletId
        }
        return id
    }

    func holdsIntegratorApproval(
        _ key: PerpsIntegratorApprovalKey,
        ttlMs: Int64,
        store: LighterCredentialsStore
    ) throws -> Bool {
        let renewalDeadline = try checkedAdd(
            PerpsServerClock.shared.signingNowUnixMs(),
            min(Self.integratorApprovalRenewalWindowMs, ttlMs / 2),
            name: "integrator approval renewal window"
        )
        guard let approved = try store.loadIntegratorApproval() else { return false }
        return approved.key == key && approved.expiry >= renewalDeadline
    }

    /// A wallet with no account yet registers its key with the deposit that creates one. Keeping
    /// the key now — with the wallet auth key the read-only token is signed with — lets the account
    /// that deposit creates trade without another unlock (`adoptRegisteredTradingKey`).
    func keepTradingKey(wallet: Wallet, cryptoWallet: MnemonicWallet) async {
        do {
            try await credentialsStore(wallet: wallet).keepTradingKey(cryptoWallet: cryptoWallet)
        } catch {
            Log.perps.w("trading key not kept wallet=\(walletLogId(wallet))", error: error)
        }
        await persistWalletAuthKeyIfMissing(wallet: wallet, cryptoWallet: cryptoWallet)
    }

    func tradingPublicKey(keySource: PerpetualAccountKeySource) async throws -> String {
        let key: KotlinByteArray = try await bridgeKotlin { completion in
            keySource.deriveTradingKey(completionHandler: completion)
        }
        return Self.tradingPublicKey(privateKey: key.asData)
    }

    func persistActivationCredentials(
        wallet: Wallet,
        keySource: PerpetualAccountKeySource,
        accountIndex: Int64
    ) async throws {
        let key: KotlinByteArray = try await bridgeKotlin { completion in
            keySource.deriveTradingKey(completionHandler: completion)
        }
        let store = credentialsStore(wallet: wallet)
        try store.saveL2PrivateKey(key.asData)
        try store.saveAccount(
            PerpsStoredAccount(
                accountIndex: accountIndex,
                apiKeyIndex: Self.apiKeyIndex,
                keyDerivationIndex: Self.keyDerivationIndex
            )
        )
    }

    func credentialsStore(wallet: Wallet) -> LighterCredentialsStore {
        LighterCredentialsStore(
            keychainVault: keychainVault,
            walletId: wallet.id,
            environment: PerpsEnvironment.storage
        )
    }
}

private func checkedAdd(_ lhs: Int64, _ rhs: Int64, name: String) throws -> Int64 {
    let (value, overflow) = lhs.addingReportingOverflow(rhs)
    guard !overflow else {
        throw PerpsTradingError.validation("\(name) overflows")
    }
    return value
}

private func int32(_ value: Int, name: String) throws -> Int32 {
    guard value >= 0, let result = Int32(exactly: value) else {
        throw PerpsTradingError.validation("\(name) is out of range")
    }
    return result
}
