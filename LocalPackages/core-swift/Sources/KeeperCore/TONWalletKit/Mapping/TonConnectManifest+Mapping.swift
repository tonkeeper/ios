//
//  TonConnectManifest+Mapping.swift
//  WalletCore
//
//  Created by Nikita Rodionov on 16.02.2026.
//

import Foundation
import TONWalletKit

public extension TonConnectManifest {
    init?(dAppInfo: TONDAppInfo) {
        guard let url = dAppInfo.url,
              let name = dAppInfo.name
        else {
            return nil
        }

        self = Self(
            url: url,
            name: name,
            iconUrl: dAppInfo.iconUrl,
            termsOfUseUrl: nil,
            privacyPolicyUrl: nil
        )
    }
}
