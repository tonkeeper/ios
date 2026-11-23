import Foundation
import KeeperCoreComponents
import TKLogging

public struct LoyaltyProfile: Codable, Equatable, Sendable {
    public struct Balance: Codable, Equatable, Sendable {
        public let asset: String
        public let available: String
    }

    public struct Participant: Codable, Equatable, Sendable {}

    public let showSection: Bool
    public let showBanner: Bool
    public let participant: Participant?
    public let balances: [Balance]

    enum CodingKeys: String, CodingKey {
        case showSection = "show_section"
        case showBanner = "show_banner"
        case participant
        case balances
    }

    public init(showSection: Bool, showBanner: Bool, participant: Participant? = nil, balances: [Balance]) {
        self.showSection = showSection
        self.showBanner = showBanner
        self.participant = participant
        self.balances = balances
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showSection = try container.decode(Bool.self, forKey: .showSection)
        showBanner = try container.decode(Bool.self, forKey: .showBanner)
        participant = try container.decodeIfPresent(Participant.self, forKey: .participant)
        balances = try container.decodeIfPresent([Balance].self, forKey: .balances) ?? []
    }
}

public struct LoyaltyEntry: Equatable, Sendable {
    public let showsSection: Bool
    public let showsBanner: Bool
    public let isJoined: Bool
    public let ohms: String?

    public static let hidden = LoyaltyEntry(showsSection: false, showsBanner: false, isJoined: false, ohms: nil)

    init(showsSection: Bool, showsBanner: Bool, isJoined: Bool, ohms: String?) {
        self.showsSection = showsSection
        self.showsBanner = showsBanner
        self.isJoined = isJoined
        self.ohms = ohms
    }

    init(profile: LoyaltyProfile?, isBannerHidden: Bool) {
        guard let profile, profile.showSection else {
            self = .hidden
            return
        }
        let isJoined = profile.participant != nil
        self.init(
            showsSection: true,
            showsBanner: profile.showBanner && !isBannerHidden,
            isJoined: isJoined,
            ohms: isJoined ? profile.balances.first { $0.asset == "OHM" }?.available.nonEmpty : nil
        )
    }
}

public final class LoyaltyStore: Store<LoyaltyStore.Event, [String: LoyaltyProfile]> {
    @frozen public enum Event {
        case didUpdate
    }

    private let api: LoyaltyAPI
    private let profilesVault: FileSystemVault<[String: LoyaltyProfile], String>
    private let bannerHiddenVault: FileSystemVault<[String], String>
    private let isEnabled: () -> Bool
    private let bannerHiddenLock = NSLock()
    private var loadedBannerHiddenWalletIds: Set<String>?
    private let reloadsLock = NSLock()
    private var reloads = [String: Task<Void, Never>]()

    init(
        api: LoyaltyAPI,
        profilesVault: FileSystemVault<[String: LoyaltyProfile], String>,
        bannerHiddenVault: FileSystemVault<[String], String>,
        isEnabled: @escaping () -> Bool
    ) {
        self.api = api
        self.profilesVault = profilesVault
        self.bannerHiddenVault = bannerHiddenVault
        self.isEnabled = isEnabled
        super.init(state: [:])
    }

    override public func createInitialState() -> [String: LoyaltyProfile] {
        (try? profilesVault.loadItem(key: .profiles)) ?? [:]
    }

    public func entry(for wallet: Wallet) -> LoyaltyEntry {
        guard isEnabled(), let walletId = wallet.loyaltyWalletId else { return .hidden }
        return LoyaltyEntry(profile: getState()[walletId], isBannerHidden: isBannerHidden(walletId: walletId))
    }

    public func reload(wallet: Wallet) async {
        guard isEnabled(), let walletId = wallet.loyaltyWalletId else { return }
        let task = reloadsLock.withLock {
            if let task = reloads[walletId] {
                return task
            }
            let task = Task { [weak self] in
                await self?.load(wallet: wallet, walletId: walletId)
                self?.reloadsLock.withLock { self?.reloads[walletId] = nil }
            }
            reloads[walletId] = task
            return task
        }
        await task.value
    }

    private func load(wallet: Wallet, walletId: String) async {
        let profile: LoyaltyProfile
        do {
            profile = try await api.profile(wallet: wallet)
        } catch {
            Log.w("loyalty profile is unavailable", extraInfo: ["error": "\(error)"])
            return
        }
        await withCheckedContinuation { continuation in
            var isChanged = false
            updateState { profiles in
                guard profiles[walletId] != profile else { return nil }
                isChanged = true
                var profiles = profiles
                profiles[walletId] = profile
                return StateUpdate(newState: profiles)
            } completion: { [weak self] profiles in
                if isChanged {
                    try? self?.profilesVault.saveItem(profiles, key: .profiles)
                    self?.sendEvent(.didUpdate)
                }
                continuation.resume()
            }
        }
    }

    public func hideBanner(wallet: Wallet) {
        guard let walletId = wallet.loyaltyWalletId else { return }
        let didHide = bannerHiddenLock.withLock {
            var walletIds = bannerHiddenWalletIdsLocked()
            guard walletIds.insert(walletId).inserted else { return false }
            loadedBannerHiddenWalletIds = walletIds
            try? bannerHiddenVault.saveItem(Array(walletIds), key: .bannerHiddenWalletIds)
            return true
        }
        if didHide {
            sendEvent(.didUpdate)
        }
    }

    public func resetHiddenBanners() {
        bannerHiddenLock.withLock {
            loadedBannerHiddenWalletIds = []
            try? bannerHiddenVault.saveItem([], key: .bannerHiddenWalletIds)
        }
        sendEvent(.didUpdate)
    }

    public func perpsReward(wallet: Wallet, volumeUsd: Double) async throws -> String? {
        guard isEnabled(), let walletId = wallet.loyaltyWalletId else { return nil }
        if getState()[walletId] == nil {
            await reload(wallet: wallet)
        }
        guard getState()[walletId] != nil else { throw LoyaltyAPIError.profileUnavailable }
        guard entry(for: wallet).showsSection else { return nil }
        let total = try await api.rewardEstimate(
            wallet: wallet,
            kind: "perps",
            volumeUsd: Self.volumeString(volumeUsd)
        )
        return total.positiveOhms
    }

    static func volumeString(_ volumeUsd: Double) -> String {
        var value = Decimal(string: String(volumeUsd)) ?? Decimal(volumeUsd)
        var cents = Decimal()
        NSDecimalRound(&cents, &value, 2, .down)
        return "\(cents)"
    }

    private func isBannerHidden(walletId: String) -> Bool {
        bannerHiddenLock.withLock { bannerHiddenWalletIdsLocked().contains(walletId) }
    }

    private func bannerHiddenWalletIdsLocked() -> Set<String> {
        if let loadedBannerHiddenWalletIds {
            return loadedBannerHiddenWalletIds
        }
        let walletIds = Set((try? bannerHiddenVault.loadItem(key: .bannerHiddenWalletIds)) ?? [])
        loadedBannerHiddenWalletIds = walletIds
        return walletIds
    }
}

extension String {
    var positiveOhms: String? {
        guard let amount = Decimal(string: self), amount > 0 else { return nil }
        return "\(amount)"
    }
}

private extension Wallet {
    var loyaltyWalletId: String? {
        multichainWalletId.flatMap(\.nonEmpty)
    }
}

private extension String {
    static let profiles = "loyaltyProfiles"
    static let bannerHiddenWalletIds = "loyaltyBannerHiddenWalletIds"

    var nonEmpty: String? {
        trimmingCharacters(in: .whitespaces).isEmpty ? nil : self
    }
}
