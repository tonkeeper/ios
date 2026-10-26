import Foundation
import TKLogging

enum CampaignAttributionStorage {
    static let userDefaultsKey = "campaign_attribution.records"
}

/// First-touch campaign attribution for each provider. Records stay until TK-3415
/// consumes them after the backend accepts the upload; creating a wallet does not.
public actor CampaignAttributionStore {
    public static let shared = CampaignAttributionStore()

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func capture(_ record: CampaignAttributionRecord) -> Bool {
        var records = load()
        guard records[record.provider] == nil else { return false }
        records[record.provider] = record
        save(records)
        return true
    }

    public func record(for provider: CampaignAttributionProvider) -> CampaignAttributionRecord? {
        load()[provider]
    }

    public func records() -> [CampaignAttributionRecord] {
        load().values.sorted { $0.provider.rawValue < $1.provider.rawValue }
    }

    /// Call only after the backend accepts this provider's payload.
    public func consume(_ provider: CampaignAttributionProvider) -> CampaignAttributionRecord? {
        var records = load()
        guard let record = records.removeValue(forKey: provider) else { return nil }
        save(records)
        return record
    }

    public func consumeAll() -> [CampaignAttributionRecord] {
        let records = self.records()
        guard !records.isEmpty else { return [] }
        save([:])
        return records
    }

    private func load() -> [CampaignAttributionProvider: CampaignAttributionRecord] {
        guard let data = userDefaults.data(forKey: CampaignAttributionStorage.userDefaultsKey) else {
            return [:]
        }
        do {
            let records = try JSONDecoder().decode([CampaignAttributionRecord].self, from: data)
            var loaded: [CampaignAttributionProvider: CampaignAttributionRecord] = [:]
            for record in records where loaded[record.provider] == nil {
                loaded[record.provider] = record
            }
            return loaded
        } catch {
            Log.w("Campaign attribution store reset after a decode failure", error: error)
            return [:]
        }
    }

    private func save(_ records: [CampaignAttributionProvider: CampaignAttributionRecord]) {
        let payload = records.values.sorted { $0.provider.rawValue < $1.provider.rawValue }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        userDefaults.set(data, forKey: CampaignAttributionStorage.userDefaultsKey)
    }
}
