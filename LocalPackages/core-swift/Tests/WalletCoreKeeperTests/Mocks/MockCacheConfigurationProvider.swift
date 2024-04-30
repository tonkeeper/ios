//
//  MockCacheConfigurationProvider.swift
//  
//
//  Created by Grigory on 21.6.23..
//

import Foundation
@testable import WalletCoreKeeper

final class MockCacheConfigurationProvider: CacheConfigurationProvider {
    
    var configuration: RemoteConfiguration {
        get throws {
            if let _configuration = _configuration {
                return _configuration
            }
            throw NSError(domain: "", code: 0)
        }
    }
    
    var _configuration: RemoteConfiguration?
    
    func saveConfiguration(_ configuration: WalletCoreKeeper.RemoteConfiguration) throws {
        self._configuration = configuration
    }
}
