import Foundation
import WebKit

public extension WKWebsiteDataStore {
    static func dapp(walletId: String) throws -> WKWebsiteDataStore {
        guard #available(iOS 17.0, *) else {
            return .default()
        }
        return try WKWebsiteDataStore(
            forIdentifier: UUID(
                namespace: UUID.NamespaceV5.walletWebDataSourceScope,
                name: walletId
            )
        )
    }

    func removeSiteData(host: String, keepingHosts: [String]) async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataRecords(ofTypes: types).filter { record in
            record.covers(host) && !keepingHosts.contains(where: record.covers)
        }
        await removeData(ofTypes: types, for: records)
    }
}

private extension WKWebsiteDataRecord {
    func covers(_ host: String) -> Bool {
        let host = host.lowercased()
        return host == displayName || host.hasSuffix(".\(displayName)")
    }
}
