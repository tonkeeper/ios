import ChainKit
import Foundation
import TKKeychain
import TKLogging
import TKPerpsAPI

public enum PerpsAccountStatus {
    case account(accountIndex: Int64)
    case unbound
    case noAccount(ethAddress: String)
    case unknown
    case unavailable(reason: String)
}

enum PerpsAccountActivationOutcome {
    case active(accountIndex: Int64, apiKeyIndex: Int32)
    case noAccount(ethAddress: String)
    case canceled
    case failed(PerpsTradingError)
}

public enum PerpsAccountBindOutcome {
    case bound(accountIndex: Int64?)
    case addressMismatch(expected: String, bound: String)
    case takenByAnotherWallet(reason: String)
    case failed(PerpsTradingError)
}

struct PerpsAccountSession: Sendable {
    let accountIndex: Int64
    let apiKeyIndex: Int32
}

public final class PerpsAccountService {
    private static let apiKeyIndex = LighterAuth.shared.DEFAULT_API_KEY_INDEX

    private static let accountMediator: PerpetualAccountMediator =
        CompositePerpetualMediator().getAccountMediator(chain: .lighter)

    static let registrationConfirmationAttempts = 18

    static func registrationConfirmationDelayNanoseconds(attempt: Int) -> UInt64 {
        let base: UInt64 = 500_000_000
        let cap: UInt64 = 4_000_000_000
        return min(base << UInt64(min(max(attempt, 0), 3)), cap)
    }

    static let bindDeadlineInterval: TimeInterval = 300
    static let bindUnavailableRetries = 2

    private let mnemonicAccess: MnemonicAccess
    private let keychainVault: TKKeychainVault
    private let perpsAPI: PerpsAPI
    private let bindSigner: PerpsAccountBindSigner

    private let cacheLock = NSLock()
    /// Retained across credential clears so a wallet/environment keeps one stable
    /// journal object; file access is serialized process-wide by the journal itself.
    private var pendingJournalCache = [String: PerpsPendingJournal]()

    init(
        mnemonicAccess: MnemonicAccess,
        keychainVault: TKKeychainVault,
        perpsAPI: PerpsAPI,
        bindSigner: PerpsAccountBindSigner
    ) {
        self.mnemonicAccess = mnemonicAccess
        self.keychainVault = keychainVault
        self.perpsAPI = perpsAPI
        self.bindSigner = bindSigner
    }

    public func status(wallet: Wallet) async -> PerpsAccountStatus {
        let logId = walletLogId(wallet)
        Log.i("🪵 Perps activation: status start wallet=\(logId)")
        do {
            let account = try await perpsAPI.account(walletId: walletId(wallet))
            guard let index = account.account_index else {
                Log.i("🪵 Perps activation: status no account wallet=\(logId) l1=\(account.l1_address ?? "nil") status=\(account.status?.rawValue ?? "nil")")
                guard let l1Address = account.l1_address else { return .unbound }
                return .noAccount(ethAddress: l1Address)
            }
            Log.i("🪵 Perps activation: status account=\(index) hasL2Key=\(String(describing: account.has_l2_key)) status=\(account.status?.rawValue ?? "nil") wallet=\(logId)")
            return .account(accountIndex: Int64(index))
        } catch {
            Log.w("🪵 Perps activation: status failed wallet=\(logId)", error: error)
            return .unavailable(reason: "\(error)")
        }
    }

    public func bind(wallet: Wallet, passcode: String) async -> PerpsAccountBindOutcome {
        let logId = walletLogId(wallet)
        Log.i("🪵 Perps bind: start wallet=\(logId)")
        let cryptoWallet: CryptoWallet
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
                deadline: Int64(Date().timeIntervalSince1970 + Self.bindDeadlineInterval)
            )
            Log.i("🪵 Perps bind: signed wallet=\(logId) l1=\(binding.l1Address)")
        } catch {
            Log.w("🪵 Perps bind: signing failed wallet=\(logId)", error: error)
            return .failed(.validation("failed to sign account binding: \(error)"))
        }

        let request = Components.Schemas.BindAccountRequest(
            deadline: binding.deadline,
            signature: binding.signature,
            proof: binding.proof
        )
        do {
            let account = try await postBinding(walletId: walletId, request: request, logId: logId)
            guard let bound = account.l1_address?.lowercased(), bound == binding.l1Address else {
                Log.w("🪵 Perps bind: address mismatch wallet=\(logId) signed=\(binding.l1Address) bound=\(account.l1_address ?? "nil")")
                return .addressMismatch(expected: binding.l1Address, bound: account.l1_address ?? "")
            }
            Log.i("🪵 Perps bind: bound wallet=\(logId) account=\(String(describing: account.account_index)) status=\(account.status?.rawValue ?? "nil")")
            guard let accountIndex = account.account_index.map(Int64.init) else {
                return .bound(accountIndex: nil)
            }
            if account.has_l2_key != true {
                await registerTradingKey(wallet: wallet, cryptoWallet: cryptoWallet, logId: logId)
            }
            return .bound(accountIndex: accountIndex)
        } catch let error as PerpsAPIError {
            if case let .badStatus(failure) = error, failure.httpStatus == 409 {
                Log.w("🪵 Perps bind: conflict wallet=\(logId) reason=\(failure.reason ?? failure.code ?? "unknown")")
                return .takenByAnotherWallet(reason: failure.reason ?? failure.code ?? "conflict")
            }
            Log.w("🪵 Perps bind: failed wallet=\(logId)", error: error)
            return .failed(PerpsTradingErrorMapper.map(error))
        } catch {
            Log.w("🪵 Perps bind: failed wallet=\(logId)", error: error)
            return .failed(PerpsTradingErrorMapper.map(error))
        }
    }

    func activate(
        wallet: Wallet,
        passcode: String
    ) async -> PerpsAccountActivationOutcome {
        let cryptoWallet: CryptoWallet
        do {
            cryptoWallet = try await deriveCryptoWallet(wallet: wallet, passcode: passcode)
        } catch let error as PerpsTradingError {
            return .failed(error)
        } catch {
            return .failed(PerpsTradingErrorMapper.map(error))
        }
        return await activate(wallet: wallet, cryptoWallet: cryptoWallet)
    }

    private func activate(
        wallet: Wallet,
        cryptoWallet: CryptoWallet
    ) async -> PerpsAccountActivationOutcome {
        let logId = walletLogId(wallet)
        Log.i("🪵 Perps activation: start wallet=\(logId)")
        do {
            let walletId = try walletId(wallet)
            let mediator = Self.accountMediator
            let keySource = mediator.keySource(wallet: cryptoWallet)
            let delegate = PerpsTkAccountDelegate(walletId: walletId, api: perpsAPI)
            Log.i("🪵 Perps activation: mediator start wallet=\(logId) apiKey=\(Self.apiKeyIndex)")
            let state: PerpsAccountState = try await bridgeKotlin { completion in
                mediator.activate(
                    keySource: keySource,
                    delegate: delegate,
                    apiKeyIndex: Self.apiKeyIndex,
                    nowUnixMs: Int64(Date().timeIntervalSince1970 * 1000),
                    completionHandler: completion
                )
            }
            Log.i("🪵 Perps activation: mediator finished account=\(String(describing: state.accountIndex)) hasL2Key=\(String(describing: state.hasL2Key)) status=\(state.status ?? "nil") wallet=\(logId)")
            guard let accountIndex = state.accountIndex else {
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
            Log.i("🪵 Perps activation: credentials persisted account=\(accountIndex) wallet=\(logId)")
            return .active(
                accountIndex: Int64(truncating: accountIndex),
                apiKeyIndex: Self.apiKeyIndex
            )
        } catch {
            Log.w("🪵 Perps activation: failed wallet=\(logId)", error: error)
            return .failed(PerpsTradingErrorMapper.map(error))
        }
    }

    func tradingSession(wallet: Wallet) async throws -> PerpsAccountSession? {
        guard let account = try credentialsStore(wallet: wallet).loadAccount() else { return nil }
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

    func pendingJournal(wallet: Wallet) -> PerpsPendingJournal {
        let key = cacheKey(wallet: wallet)
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return pendingJournalLocked(wallet: wallet, key: key)
    }

    public func clearCredentials(wallet: Wallet) {
        credentialsStore(wallet: wallet).clear()
    }
}

private final class PerpsTkAccountDelegate: NSObject, PerpsAccountDelegate {
    private let walletId: String
    private let api: PerpsAPI

    init(walletId: String, api: PerpsAPI) {
        self.walletId = walletId
        self.api = api
    }

    func accountState(completionHandler: @escaping (PerpsAccountState?, Error?) -> Void) {
        Log.i("🪵 Perps activation: account state request wallet=\(walletLogId(walletId))")
        Task {
            do {
                let state = try await loadAccountState()
                Log.i("🪵 Perps activation: account state response account=\(String(describing: state.accountIndex)) hasL2Key=\(String(describing: state.hasL2Key)) status=\(state.status ?? "nil") l1=\(state.l1Address ?? "nil")")
                completionHandler(state, nil)
            } catch {
                Log.w("🪵 Perps activation: account state failed wallet=\(walletLogId(walletId))", error: error)
                completionHandler(nil, error)
            }
        }
    }

    func nextNonce(
        accountIndex: Int64,
        apiKeyIndex: Int32,
        completionHandler: @escaping (KotlinLong?, Error?) -> Void
    ) {
        Log.i("🪵 Perps activation: nonce request account=\(accountIndex) apiKey=\(apiKeyIndex)")
        Task {
            do {
                let response = try await api.nextNonce(walletId: walletId, apiKeyIndex: Int(apiKeyIndex))
                guard response.account_index == accountIndex else {
                    throw PerpsTradingError.protocolFailure("nonce account does not match activation account")
                }
                Log.i("🪵 Perps activation: nonce response account=\(accountIndex) nonce=\(response.nonce)")
                completionHandler(KotlinLong(value: response.nonce), nil)
            } catch {
                Log.w("🪵 Perps activation: nonce failed account=\(accountIndex)", error: error)
                completionHandler(nil, error)
            }
        }
    }

    func submitRegistration(
        registration: PerpsAccountRegistration,
        completionHandler: @escaping (PerpsAccountSubmissionOutcome?, Error?) -> Void
    ) {
        Log.i("🪵 Perps activation: registration submit start account=\(registration.accountIndex) apiKey=\(registration.apiKeyIndex) txType=\(registration.txType)")
        Task {
            do {
                let response = try await api.sendTransactions(
                    walletId: walletId,
                    transactions: [.init(tx_type: Int32(registration.txType), tx_info: registration.txInfo)]
                )
                guard response.transactions.count == 1,
                      response.transactions[0].tx_type == Int32(registration.txType),
                      Self.normalizedHash(response.transactions[0].tx_hash) == Self.normalizedHash(registration.txHash)
                else {
                    Log.w("🪵 Perps activation: registration response mismatch account=\(registration.accountIndex) txType=\(registration.txType)")
                    completionHandler(.protocolfailure, nil)
                    return
                }
                Log.i("🪵 Perps activation: registration accepted account=\(registration.accountIndex) txType=\(registration.txType)")
                completionHandler(.accepted, nil)
            } catch let error as PerpsAPIError where error.isResignRequired {
                Log.i("🪵 Perps activation: registration resign required account=\(registration.accountIndex) txType=\(registration.txType)")
                completionHandler(.resignrequired, nil)
            } catch {
                Log.w("🪵 Perps activation: registration submit failed account=\(registration.accountIndex)", error: error)
                completionHandler(nil, error)
            }
        }
    }

    func confirmRegistration(
        registration: PerpsAccountRegistration,
        completionHandler: @escaping (PerpsAccountState?, Error?) -> Void
    ) {
        Log.i("🪵 Perps activation: confirmation start account=\(registration.accountIndex) txType=\(registration.txType)")
        Task {
            do {
                for attempt in 0 ..< PerpsAccountService.registrationConfirmationAttempts {
                    let state = try await loadAccountState()
                    if state.hasL2Key == true {
                        Log.i("🪵 Perps activation: confirmation success account=\(registration.accountIndex) attempt=\(attempt + 1)")
                        completionHandler(state, nil)
                        return
                    }
                    if attempt == 0 || attempt == 9 {
                        Log.i("🪵 Perps activation: confirmation pending account=\(registration.accountIndex) attempt=\(attempt + 1)")
                    }
                    try await Task.sleep(
                        nanoseconds: PerpsAccountService.registrationConfirmationDelayNanoseconds(attempt: attempt)
                    )
                }
                Log.w("🪵 Perps activation: confirmation timeout account=\(registration.accountIndex)")
                completionHandler(nil, PerpsTradingError.protocolFailure("account key registration confirmation timed out"))
            } catch {
                Log.w("🪵 Perps activation: confirmation failed account=\(registration.accountIndex)", error: error)
                completionHandler(nil, error)
            }
        }
    }

    private static func normalizedHash(_ hash: String) -> String {
        let value = hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
    }

    private func loadAccountState() async throws -> PerpsAccountState {
        let account = try await api.account(walletId: walletId)
        return PerpsAccountState(
            accountIndex: account.account_index.map { KotlinLong(value: Int64($0)) },
            l1Address: account.l1_address,
            status: account.status?.rawValue,
            hasL2Key: account.has_l2_key.map { KotlinBoolean(value: $0) },
            collateral: account.collateral,
            availableBalance: account.available_balance
        )
    }
}

private func walletLogId(_ walletId: String) -> String {
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
    func registerTradingKey(wallet: Wallet, cryptoWallet: CryptoWallet, logId: String) async {
        switch await activate(wallet: wallet, cryptoWallet: cryptoWallet) {
        case let .active(accountIndex, apiKeyIndex):
            Log.i("🪵 Perps bind: trading key registered account=\(accountIndex) apiKey=\(apiKeyIndex) wallet=\(logId)")
        case .noAccount:
            Log.i("🪵 Perps bind: trading key deferred — no account yet wallet=\(logId)")
        case .canceled:
            Log.i("🪵 Perps bind: trading key registration canceled wallet=\(logId)")
        case let .failed(error):
            Log.w("🪵 Perps bind: trading key registration failed \(error) wallet=\(logId)")
        }
    }

    func deriveCryptoWallet(wallet: Wallet, passcode: String) async throws -> CryptoWallet {
        let logId = walletLogId(wallet)
        let phrase: String
        do {
            let mnemonic = try await mnemonicAccess.getMnemonic(wallet: wallet, passcode: passcode)
            Log.i("🪵 Perps: mnemonic loaded type=\(mnemonic.type) wallet=\(logId)")
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
            Log.w("🪵 Perps: mnemonic load failed wallet=\(logId)", error: error)
            throw PerpsTradingError.validation("failed to read mnemonic: \(error)")
        }
        do {
            let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: phrase)
            Log.i("🪵 Perps: wallet derivation ready wallet=\(logId)")
            return cryptoWallet
        } catch {
            Log.w("🪵 Perps: wallet derivation failed wallet=\(logId)", error: error)
            throw PerpsTradingError.validation("failed to derive wallet: \(error)")
        }
    }

    func postBinding(
        walletId: String,
        request: Components.Schemas.BindAccountRequest,
        logId: String
    ) async throws -> Components.Schemas.Account {
        var lastError: Error?
        for attempt in 0 ... Self.bindUnavailableRetries {
            do {
                return try await perpsAPI.bindAccount(walletId: walletId, request: request)
            } catch let error as PerpsAPIError {
                guard case let .badStatus(failure) = error, failure.httpStatus == 503 else { throw error }
                Log.i("🪵 Perps bind: upstream unavailable wallet=\(logId) attempt=\(attempt + 1)")
                lastError = error
                if attempt < Self.bindUnavailableRetries {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        throw lastError ?? PerpsTradingError.protocolFailure("account binding did not complete")
    }

    func walletId(_ wallet: Wallet) throws -> String {
        guard let id = wallet.multichainWalletState?.walletId, !id.isEmpty else {
            throw PerpsAccountReadError.missingWalletId
        }
        return id
    }

    func persistActivationCredentials(
        wallet: Wallet,
        keySource: PerpetualAccountKeySource,
        accountIndex: Int64
    ) async throws {
        let key: KotlinByteArray = try await bridgeKotlin { completion in
            keySource.deriveTradingKey(accountIndex: accountIndex, completionHandler: completion)
        }
        let store = credentialsStore(wallet: wallet)
        try store.saveL2PrivateKey(key.asData)
        try store.saveAccount(
            PerpsStoredAccount(accountIndex: accountIndex, apiKeyIndex: Self.apiKeyIndex)
        )
    }

    func cacheKey(wallet: Wallet) -> String {
        wallet.id
    }

    func pendingJournalLocked(
        wallet: Wallet,
        key: String
    ) -> PerpsPendingJournal {
        if let cached = pendingJournalCache[key] {
            return cached
        }
        let journal = PerpsPendingJournal(
            walletId: wallet.id,
            environment: "production"
        )
        pendingJournalCache[key] = journal
        return journal
    }

    func credentialsStore(wallet: Wallet) -> LighterCredentialsStore {
        LighterCredentialsStore(
            keychainVault: keychainVault,
            walletId: wallet.id,
            environment: "production"
        )
    }
}
