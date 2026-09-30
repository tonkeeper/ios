import Foundation
@testable import KeeperCore

struct MultichainServiceFake: MultichainService {
    enum WalletAssets {
        case listing([MultichainAsset])
        case failure
    }

    /// Outcomes are consumed in order; the last one keeps repeating.
    final class WalletAssetsScript: @unchecked Sendable {
        private let lock = NSLock()
        private var outcomes: [WalletAssets]

        init(_ outcomes: [WalletAssets]) {
            self.outcomes = outcomes
        }

        func next() -> WalletAssets {
            lock.lock()
            defer { lock.unlock() }
            if outcomes.count > 1 {
                return outcomes.removeFirst()
            }
            return outcomes.first ?? .failure
        }
    }

    final class RequestLog: @unchecked Sendable {
        private let lock = NSLock()
        private var requestedAssetIds: [[String]?] = []

        var assetIds: [[String]?] {
            lock.lock()
            defer { lock.unlock() }
            return requestedAssetIds
        }

        func record(assetIds: [String]?) {
            lock.lock()
            defer { lock.unlock() }
            requestedAssetIds.append(assetIds)
        }
    }

    /// Single-use challenges handed out in order, so a re-signed batch can be told apart.
    final class WalletChallengeScript: @unchecked Sendable {
        private let lock = NSLock()
        private var challenges: [String]

        init(_ challenges: [String]) {
            self.challenges = challenges
        }

        func next() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return challenges.isEmpty ? nil : challenges.removeFirst()
        }
    }

    var walletAssets: WalletAssets = .failure
    var walletAssetsScript: WalletAssetsScript?
    let requests = RequestLog()
    var walletChallengeScript: WalletChallengeScript?

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        throw .connectionError
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw .connectionError
    }

    func getWallet(walletId _: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .connectionError
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus {
        throw .connectionError
    }

    func getWalletAssets(
        state _: MultichainWalletState,
        currencies _: [String],
        assetIds: [String]?,
        capabilities _: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly _: Bool?,
        showHidden _: Bool?,
        hideDust _: Bool?,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        requests.record(assetIds: assetIds)
        switch walletAssetsScript?.next() ?? walletAssets {
        case let .listing(assets):
            let filtered = assetIds.map { ids in
                assets.filter { ids.contains($0.asset.assetId) }
            } ?? assets
            return MultichainWalletAssetsPage(assets: filtered, nextCursor: nil, fiatPrice: [:])
        case .failure:
            throw .connectionError
        }
    }

    func saveWalletAssetsFilters(
        walletId _: String,
        changes _: [MultichainAssetFilterChange]
    ) async throws(MultichainServiceError) {
        throw .connectionError
    }

    func getWalletActivities(
        state _: MultichainWalletState,
        limit _: Int?,
        cursor _: String?,
        chain _: MultichainChain?,
        assetId _: String?,
        activityTypeFilter _: MultichainActivityTypeFilter?,
        showPerps _: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        throw .connectionError
    }

    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge {
        guard let challenge = walletChallengeScript?.next() else {
            throw .connectionError
        }
        return MultichainWalletChallenge(challenge: challenge, expiresAt: Date())
    }

    func broadcastTx(
        chain _: MultichainChain,
        signedTransaction _: Data
    ) async throws(MultichainServiceError) -> MultichainBroadcastResult {
        throw .connectionError
    }

    func getFees(chain _: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate {
        throw .connectionError
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainServiceError) -> [MultichainRaffle] {
        throw .connectionError
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainServiceError) {
        throw .connectionError
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainServiceError) {
        throw .connectionError
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainServiceError) {
        throw .connectionError
    }
}
