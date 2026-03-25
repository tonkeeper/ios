import CoreComponents
import Foundation

struct OnRampCacheEntry<T: Codable>: Codable {
    let value: T
    let cachedAt: Date
}

enum OnRampCachedValue: Codable {
    case merchants(OnRampCacheEntry<[OnRampMerchantInfo]>)
    case layout(OnRampCacheEntry<OnRampLayout>)
}

protocol OnRampRepository {
    func getMerchants() throws -> (data: [OnRampMerchantInfo], cachedAt: Date)?
    func saveMerchants(_ data: [OnRampMerchantInfo]) throws

    func getLayout(flow: String, currency: String?) throws -> (data: OnRampLayout, cachedAt: Date)?
    func saveLayout(_ data: OnRampLayout, flow: String, currency: String?) throws

    func clearCache()
}

final class OnRampRepositoryImplementation: OnRampRepository {
    private let fileSystemVault: FileSystemVault<OnRampCachedValue, String>

    init(fileSystemVault: FileSystemVault<OnRampCachedValue, String>) {
        self.fileSystemVault = fileSystemVault
    }

    func getMerchants() throws -> (data: [OnRampMerchantInfo], cachedAt: Date)? {
        guard case let .merchants(entry) = try? fileSystemVault.loadItem(key: Self.merchantsKey) else {
            return nil
        }
        return (entry.value, entry.cachedAt)
    }

    func saveMerchants(_ data: [OnRampMerchantInfo]) throws {
        try fileSystemVault.saveItem(.merchants(OnRampCacheEntry(value: data, cachedAt: Date())), key: Self.merchantsKey)
    }

    func getLayout(flow: String, currency: String?) throws -> (data: OnRampLayout, cachedAt: Date)? {
        guard case let .layout(entry) = try? fileSystemVault.loadItem(key: Self.layoutKey(flow: flow, currency: currency)) else {
            return nil
        }
        return (entry.value, entry.cachedAt)
    }

    func saveLayout(_ data: OnRampLayout, flow: String, currency: String?) throws {
        try fileSystemVault.saveItem(
            .layout(OnRampCacheEntry(value: data, cachedAt: Date())),
            key: Self.layoutKey(flow: flow, currency: currency)
        )
    }

    func clearCache() {
        fileSystemVault.deleteAllItems()
    }
}

private extension OnRampRepositoryImplementation {
    static let merchantsKey = "OnRamp_Merchants"

    static func layoutKey(flow: String, currency: String?) -> String {
        "OnRamp_Layout_\(flow)_\(currency ?? "nil")"
    }
}
