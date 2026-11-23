import Foundation
import KeeperCore
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
        try TKBridgeWebViewController.Configuration(
            copyToastConfiguration: .copied,
            websiteDataStore: walletIdentifier.map(WKWebsiteDataStore.dapp(walletId:)),
            applicationNameForUserAgent: applicationNameForUserAgent,
            showsInitialLoadingIndicator: showsInitialLoadingIndicator,
            allowsBackForwardNavigationGestures: allowsBackForwardNavigationGestures
        )
    }
}
