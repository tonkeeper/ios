import Foundation
import KeeperCoreComponents

struct OnRampCacheEntry<T: Codable>: Codable {
    let value: T
    let cachedAt: Date
}

enum OnRampCachedValue: Codable {
    case merchants(OnRampCacheEntry<[OnRampMerchantInfo]>)
    case layout(OnRampCacheEntry<OnRampLayout>)
}

/// The backend picks the on-ramp providers from the wallet the request carries, so a response
/// cached for one wallet must not be replayed for another.
protocol OnRampRepository {
    func getMerchants(walletId: String?) throws -> (data: [OnRampMerchantInfo], cachedAt: Date)?
    func saveMerchants(_ data: [OnRampMerchantInfo], walletId: String?) throws

    func getLayout(flow: String, currency: String?, walletId: String?) throws -> (data: OnRampLayout, cachedAt: Date)?
    func saveLayout(_ data: OnRampLayout, flow: String, currency: String?, walletId: String?) throws

    func clearCache()
}

final class OnRampRepositoryImplementation: OnRampRepository {
    private let fileSystemVault: FileSystemVault<OnRampCachedValue, String>

    init(fileSystemVault: FileSystemVault<OnRampCachedValue, String>) {
        self.fileSystemVault = fileSystemVault
    }

    func getMerchants(walletId: String?) throws -> (data: [OnRampMerchantInfo], cachedAt: Date)? {
        guard case let .merchants(entry) = try? fileSystemVault.loadItem(key: Self.merchantsKey(walletId: walletId)) else {
            return nil
        }
        return (entry.value, entry.cachedAt)
    }

    func saveMerchants(_ data: [OnRampMerchantInfo], walletId: String?) throws {
        try fileSystemVault.saveItem(
            .merchants(OnRampCacheEntry(value: data, cachedAt: Date())),
            key: Self.merchantsKey(walletId: walletId)
        )
    }

    func getLayout(flow: String, currency: String?, walletId: String?) throws -> (data: OnRampLayout, cachedAt: Date)? {
        let key = Self.layoutKey(flow: flow, currency: currency, walletId: walletId)
        guard case let .layout(entry) = try? fileSystemVault.loadItem(key: key) else {
            return nil
        }
        return (entry.value, entry.cachedAt)
    }

    func saveLayout(_ data: OnRampLayout, flow: String, currency: String?, walletId: String?) throws {
        try fileSystemVault.saveItem(
            .layout(OnRampCacheEntry(value: data, cachedAt: Date())),
            key: Self.layoutKey(flow: flow, currency: currency, walletId: walletId)
        )
    }

    func clearCache() {
        fileSystemVault.deleteAllItems()
    }
}

private extension OnRampRepositoryImplementation {
    static func merchantsKey(walletId: String?) -> String {
        "OnRamp_Merchants_\(walletId ?? "nil")"
    }

    static func layoutKey(flow: String, currency: String?, walletId: String?) -> String {
        "OnRamp_Layout_\(flow)_\(currency ?? "nil")_\(walletId ?? "nil")"
    }
}
