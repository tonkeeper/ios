//
//  MockDefaultConfigurationProvider.swift
//  
//
//  Created by Grigory on 21.6.23..
//

import Foundation
@testable import WalletCoreKeeper

final class MockDefaultConfigurationProvider: ConfigurationProvider {
    var configuration: WalletCoreKeeper.RemoteConfiguration {
        .empty
    }
}
