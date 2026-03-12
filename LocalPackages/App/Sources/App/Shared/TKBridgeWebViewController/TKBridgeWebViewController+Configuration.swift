import Foundation
import os
import TKScreenKit
import WebKit

extension TKBridgeWebViewController.Configuration {
    static var `default`: TKBridgeWebViewController.Configuration {
        TKBridgeWebViewController.Configuration(copyToastConfiguration: .copied)
    }

    static func dapp(walletIdentifier: String?) throws -> TKBridgeWebViewController.Configuration {
        guard let walletIdentifier else {
            return .default
        }
        guard #available(iOS 17.0, *) else {
            return .default
        }
        let dataStoreUuid = try UUID(
            namespace: UUID.NamespaceV5.walletWebDataSourceScope,
            name: walletIdentifier
        )
        let dataStore = WKWebsiteDataStore(
            forIdentifier: dataStoreUuid
        )
        return TKBridgeWebViewController.Configuration(
            copyToastConfiguration: .copied,
            websiteDataStore: dataStore
        )
    }
}
