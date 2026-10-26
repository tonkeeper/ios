import Foundation
import TKBatteryAPI
import TKLogging

/// The relayer's config is kept for `lifetime`; one that cannot be read leaves the last one in force.
actor EVMGaslessRelayedChains {
    private let loadConfig: @Sendable () async throws -> Components.Schemas.GaslessV2Config
    private let lifetime: TimeInterval
    private let now: () -> Date
    private var cached: (chains: Set<MultichainChain>, loadedAt: Date)?
    private var loading: Task<Set<MultichainChain>?, Never>?
    private var loadGeneration = 0

    init(
        loadConfig: @escaping @Sendable () async throws -> Components.Schemas.GaslessV2Config,
        lifetime: TimeInterval = 15 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.loadConfig = loadConfig
        self.lifetime = lifetime
        self.now = now
    }

    /// `nil` until a config has been read.
    func chains() async -> Set<MultichainChain>? {
        if let cached, now().timeIntervalSince(cached.loadedAt) < lifetime {
            return cached.chains
        }
        if let loading {
            return await loading.value ?? cached?.chains
        }

        loadGeneration += 1
        let generation = loadGeneration
        let task = Task { [loadConfig] () -> Set<MultichainChain>? in
            do {
                let config = try await loadConfig()
                return Self.relayedEVMChains(in: config)
            } catch {
                Log.multichain.w("gasless config failed, the relayed chains known so far stay in force", error: error)
                return nil
            }
        }
        loading = task
        let loaded = await task.value
        if loadGeneration == generation {
            loading = nil
            if let loaded {
                cached = (loaded, now())
            }
        }
        return loaded ?? cached?.chains
    }

    static func relayedEVMChains(in config: Components.Schemas.GaslessV2Config) -> Set<MultichainChain> {
        Set(
            config.chains
                .filter { $0.payload_types.contains(EVMGaslessCall.payloadType) }
                .compactMap { MultichainChain(relayerChainId: $0.chain_id) }
                .filter(\.isEVM)
        )
    }
}
