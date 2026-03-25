//
//  TonConnectParameters+Mapping.swift
//  WalletCore
//
//  Created by Nikita Rodionov on 16.02.2026.
//

import Foundation
import TONWalletKit

public extension TonConnectParameters {
    init(event: TONConnectionRequestEvent, manifestUrl: URL) {
        let items: [TonConnectRequestPayload.Item] = event.requestedItems.compactMap { item in
            switch item {
            case .tonAddr:
                return .tonAddress
            case let .tonProof(proofItem):
                return .tonProof(payload: proofItem.payload)
            case .unknown:
                return .unknown
            }
        }

        let requestPayload = TonConnectRequestPayload(
            manifestUrl: manifestUrl,
            items: items
        )

        self = Self(
            version: .v2,
            clientId: event.from ?? UUID().uuidString,
            requestPayload: requestPayload,
            returnStrategy: event.returnStrategy
        )
    }
}
