import Foundation
import os
import TKScreenKit
import WebKit

extension TKBridgeWebViewController.Configuration {
    static var `default`: TKBridgeWebViewController.Configuration {
        TKBridgeWebViewController.Configuration(copyToastConfiguration: .copied)
    }

    static func dapp(
        walletIdentifier: String?,
        applicationNameForUserAgent: String? = nil,
        showsInitialLoadingIndicator: Bool = false,
        allowsBackForwardNavigationGestures: Bool = false
    ) throws -> TKBridgeWebViewController.Configuration {
        var websiteDataStore: WKWebsiteDataStore?
        if let walletIdentifier, #available(iOS 17.0, *) {
            let dataStoreUuid = try UUID(
                namespace: UUID.NamespaceV5.walletWebDataSourceScope,
                name: walletIdentifier
            )
            websiteDataStore = WKWebsiteDataStore(forIdentifier: dataStoreUuid)
        }
        return TKBridgeWebViewController.Configuration(
            copyToastConfiguration: .copied,
            websiteDataStore: websiteDataStore,
            applicationNameForUserAgent: applicationNameForUserAgent,
            showsInitialLoadingIndicator: showsInitialLoadingIndicator,
            allowsBackForwardNavigationGestures: allowsBackForwardNavigationGestures
        )
    }
}
