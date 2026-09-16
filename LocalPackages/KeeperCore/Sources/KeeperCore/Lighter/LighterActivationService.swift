import ChainKit
import Foundation
import TKFeatureFlags
import TKKeychain
import TKLogging

public enum LighterPerpsStatus {
    case active(accountIndex: Int64, apiKeyIndex: Int32)
    case accountExists(accountIndex: Int64)
    case noAccount(ethAddress: String)
    case unknown
    case unavailable(reason: String)
}

public enum LighterActivationOutcome {
    case active(accountIndex: Int64, apiKeyIndex: Int32)
    case noAccount(ethAddress: String)
    case canceled
    case failed(PerpsTradingError)
}

public final class LighterActivationService: PerpsAccountReading {
    private let mnemonicAccess: MnemonicAccess
    private let keychainVault: TKKeychainVault
    private let configuration: Configuration

    private let cacheLock = NSLock()
    private var kitCache = [String: LighterKit]()
    private var probeCache = [String: LighterPerps]()
    // Retained across credential clears so a wallet/environment keeps one stable
    // store object; file access is serialized process-wide by the store itself.
    private var operationStoreCache = [String: LighterOperationFileStore]()
    private lazy var sharedHttpClient = LighterHttpClient_iosKt.createLighterHttpClient()

    init(
        mnemonicAccess: MnemonicAccess,
        keychainVault: TKKeychainVault,
        configuration: Configuration
    ) {
        self.mnemonicAccess = mnemonicAccess
        self.keychainVault = keychainVault
        self.configuration = configuration
    }

    public func status(wallet: Wallet) async -> LighterPerpsStatus {
        let kit = kit(wallet: wallet)

        do {
            if let session: LighterSession = try await bridgeKotlinOptional({ kit.session(completionHandler: $0) }) {
                return .active(accountIndex: session.accountIndex, apiKeyIndex: session.apiKeyIndex)
            }
        } catch {
            Log.w("🪵 Lighter: status session read failed — \(error)")
            return .unavailable(reason: "\(error)")
        }

        let store = credentialsStore(wallet: wallet)
        let storedEthAddress = store.loadL1Address()
        let fallbackEthAddress = wallet.multichainEthereumAddress
        guard let ethAddress = storedEthAddress ?? fallbackEthAddress else {
            return .unknown
        }
        do {
            let accountIndex: KotlinLong? = try await bridgeKotlinOptional {
                probe(wallet: wallet).accountIndex(l1Address: ethAddress, completionHandler: $0)
            }
            store.saveL1Address(ethAddress)
            if let accountIndex {
                return .accountExists(accountIndex: accountIndex.int64Value)
            }
            return .noAccount(ethAddress: ethAddress)
        } catch {
            return .unavailable(reason: "\(error)")
        }
    }

    public var isTestnet: Bool {
        configuration.lighterAPIEnvironment == .testnet
    }

    public func activate(
        wallet: Wallet,
        passcode: String
    ) async -> LighterActivationOutcome {
        let phrase: String
        do {
            let mnemonic = try await mnemonicAccess.getMnemonic(wallet: wallet, passcode: passcode)
            switch mnemonic.type {
            case .bip39:
                break
            case .bip39soft:
                return .failed(.validation("recovery phrase checksum invalid"))
            case .ton, .unknown:
                return .failed(.validation("wallet mnemonic is not BIP39 — perps unsupported for this wallet"))
            }
            phrase = mnemonic.mnemonicWords.joined(separator: " ")
        } catch {
            return .failed(.validation("failed to read mnemonic: \(error)"))
        }

        let cryptoWallet: CryptoWallet
        do {
            cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: phrase)
        } catch {
            return .failed(.validation("failed to derive wallet: \(error)"))
        }
        let kit = kit(wallet: wallet)
        credentialsStore(wallet: wallet)
            .saveL1Address(cryptoWallet.getAddress(chain: ChainEthereumMainnet.shared).display)

        Log.i("🪵 Lighter: activation started (\(configuration.lighterAPIEnvironment.rawValue))")
        do {
            let state: ActivationState = try await bridgeKotlin { completion in
                kit.activate(wallet: cryptoWallet, completionHandler: completion)
            }
            return outcome(from: state)
        } catch {
            return .failed(PerpsTradingErrorMapper.map(error))
        }
    }

    func tradingSession(wallet: Wallet) async throws -> LighterSession? {
        let kit = kit(wallet: wallet)
        return try await bridgeKotlinOptional { kit.session(completionHandler: $0) }
    }

    func operationStore(wallet: Wallet) -> LighterOperationFileStore {
        let environment = configuration.lighterAPIEnvironment
        let key = cacheKey(wallet: wallet, environment: environment)
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return operationStoreLocked(wallet: wallet, environment: environment, key: key)
    }

    func portfolio(wallet: Wallet, accountIndex: Int64) async throws -> PerpsPortfolio? {
        let kit = kit(wallet: wallet)
        return try await bridgeKotlinOptional { kit.reads.portfolio(accountIndex: accountIndex, completionHandler: $0) }
    }

    /// Lighter gates `accountActiveOrders` behind an auth token, so this reads through
    /// the authenticated session (`session.reads`), not the public `kit.reads`.
    public func activeTriggerOrders(wallet: Wallet, accountIndex: Int64, marketId: Int64) async throws -> [PerpsTriggerOrderSummary] {
        try await activeOrders(wallet: wallet, accountIndex: accountIndex, marketId: marketId)
            .compactMap(PerpsTriggerOrderSummary.init(order:))
    }

    public func activeMarketOrders(wallet: Wallet, accountIndex: Int64, marketId: Int64) async throws -> PerpsActiveOrders {
        let orders = try await activeOrders(wallet: wallet, accountIndex: accountIndex, marketId: marketId)
        return PerpsActiveOrders(
            limitOrders: orders.compactMap(PerpsLimitOrderSummary.init(order:)),
            triggerOrders: orders.compactMap(PerpsTriggerOrderSummary.init(order:))
        )
    }

    func activeOrders(wallet: Wallet, accountIndex: Int64, marketId: Int64) async throws -> [PerpsOrder] {
        guard let session = try await tradingSession(wallet: wallet) else { return [] }
        return try await bridgeKotlinOptional {
            session.reads.activeOrders(
                accountIndex: accountIndex,
                marketId: KotlinLong(value: marketId),
                completionHandler: $0
            )
        } ?? []
    }

    func inactiveOrders(wallet: Wallet, accountIndex: Int64, marketId: Int64) async throws -> [PerpsOrder] {
        guard let session = try await tradingSession(wallet: wallet) else { return [] }
        return try await bridgeKotlin {
            session.reads.inactiveOrders(
                accountIndex: accountIndex,
                marketId: KotlinLong(value: marketId),
                limit: 50,
                completionHandler: $0
            )
        }
    }

    /// Lighter gates `recentActivity` behind an auth token, so this reads through the
    /// authenticated session (`session.reads`), not the public `kit.reads`.
    public func recentActivity(wallet: Wallet, accountIndex: Int64, marketId: Int64, limit: Int) async throws -> [PerpsActivityItem] {
        guard let l1Address = credentialsStore(wallet: wallet).loadL1Address() ?? wallet.multichainEthereumAddress else { return [] }
        guard let session = try await tradingSession(wallet: wallet) else { return [] }
        let apiLimit = Int64(max(limit * 10, 50))
        let page = try await bridgeKotlinOptional {
            session.reads.recentActivity(accountIndex: accountIndex, l1Address: l1Address, limit: apiLimit, completionHandler: $0)
        }
        let items = (page?.items ?? []).map(PerpsActivityItem.init(activity:))
        return Array(items.filter { $0.marketId == marketId }.prefix(limit))
    }

    /// Live positions stream for the account, mapped to Core models — public data,
    /// no credentials needed.
    public func watchPositions(
        wallet: Wallet,
        accountIndex: Int64,
        onUpdate: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onReconnecting: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        let handle = kit(wallet: wallet).watchPositions(
            accountIndex: accountIndex,
            onUpdate: { positions in onUpdate(positions.compactMap(PerpsPositionSummary.init(position:))) },
            onReconnecting: { cause in
                Log.i("🪵 Lighter: positions stream reconnecting — \(cause ?? "unknown")")
                onReconnecting()
            }
        )
        return PerpsPositionsWatch { handle.cancel() }
    }

    public func watchTransactionUpdates(
        wallet: Wallet,
        onUpdate: @escaping @Sendable () -> Void,
        onReconnecting: @escaping @Sendable () -> Void
    ) async throws -> PerpsTransactionUpdatesWatch? {
        guard let session = try await tradingSession(wallet: wallet) else { return nil }
        let handle = session.watchTransactionUpdates(
            onUpdate: { _ in onUpdate() },
            onReconnecting: { cause in
                Log.i("🪵 Lighter: transaction stream reconnecting — \(cause ?? "unknown")")
                onReconnecting()
            }
        )
        return PerpsTransactionUpdatesWatch { handle.cancel() }
    }

    public func clearCredentials(wallet: Wallet) {
        cacheLock.lock()
        for environment in LighterAPIEnvironment.allCases {
            let key = cacheKey(wallet: wallet, environment: environment)
            kitCache[key]?.close()
            kitCache.removeValue(forKey: key)
            probeCache.removeValue(forKey: key)
        }
        cacheLock.unlock()

        for environment in LighterAPIEnvironment.allCases {
            credentialsStore(wallet: wallet, environment: environment).clear()
        }
    }
}

private extension LighterActivationService {
    func kit(wallet: Wallet) -> LighterKit {
        let environment = configuration.lighterAPIEnvironment
        let key = cacheKey(wallet: wallet, environment: environment)

        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = kitCache[key] {
            return cached
        }
        let kit = LighterKit_iosKt.makeLighterKit(
            environment: environment.asChainKitEnvironment,
            keyStore: credentialsStore(wallet: wallet, environment: environment),
            operationStore: operationStoreLocked(wallet: wallet, environment: environment, key: key),
            httpClient: sharedHttpClient
        )
        kitCache[key] = kit
        return kit
    }

    func probe(wallet: Wallet) -> LighterPerps {
        let environment = configuration.lighterAPIEnvironment
        let key = cacheKey(wallet: wallet, environment: environment)

        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = probeCache[key] {
            return cached
        }
        let probe = LighterPerps(
            environment: environment.asChainKitEnvironment,
            keyStore: credentialsStore(wallet: wallet, environment: environment),
            httpClient: sharedHttpClient,
            apiKeyIndex: LighterAuth.shared.DEFAULT_API_KEY_INDEX,
            lighter: makeLighterClient(),
            operationStore: InMemoryLighterOperationStore()
        )
        probeCache[key] = probe
        return probe
    }

    func makeLighterClient() -> LighterClient {
        LighterClient(
            crypto: LighterCryptoBridge(crypto: CoreLighterCrypto()),
            nowMillis: { KotlinLong(value: Int64(Date().timeIntervalSince1970 * 1000)) }
        )
    }

    func cacheKey(wallet: Wallet, environment: LighterAPIEnvironment) -> String {
        "\(wallet.id)/\(environment.rawValue)"
    }

    func operationStoreLocked(
        wallet: Wallet,
        environment: LighterAPIEnvironment,
        key: String
    ) -> LighterOperationFileStore {
        if let cached = operationStoreCache[key] {
            return cached
        }
        let store = LighterOperationFileStore(
            walletId: wallet.id,
            environment: environment.rawValue
        )
        operationStoreCache[key] = store
        return store
    }

    func credentialsStore(wallet: Wallet) -> LighterCredentialsStore {
        credentialsStore(wallet: wallet, environment: configuration.lighterAPIEnvironment)
    }

    func credentialsStore(wallet: Wallet, environment: LighterAPIEnvironment) -> LighterCredentialsStore {
        LighterCredentialsStore(
            keychainVault: keychainVault,
            walletId: wallet.id,
            environment: environment.rawValue
        )
    }

    func outcome(from state: ActivationState) -> LighterActivationOutcome {
        switch state {
        case let active as ActivationStateActive:
            Log.i("🪵 Lighter: activation state — active")
            return .active(accountIndex: active.accountIndex, apiKeyIndex: active.apiKeyIndex)
        case let noAccount as ActivationStateNoAccount:
            Log.i("🪵 Lighter: activation state — no account (deposit first)")
            return .noAccount(ethAddress: noAccount.ethAddress)
        default:
            return .failed(.protocolFailure("unexpected activation state: \(state)"))
        }
    }
}

private extension LighterAPIEnvironment {
    var asChainKitEnvironment: LighterEnvironment {
        switch self {
        case .production:
            return LighterEnvironment.Mainnet.shared
        case .testnet:
            return LighterEnvironment.Staging.shared
        }
    }
}
