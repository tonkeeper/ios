//
//  RemoteConfigurationTests.swift
//  
//
//  Created by Grigory on 20.6.23..
//

import XCTest
import TonAPI
@testable import WalletCoreKeeper

final class RemoteConfigurationTests: XCTestCase {
    func testRemoteConfigurationModelDecoding() throws {
        let configurationResponseString = """
        {
          "tonapiV2Endpoint": "https://tonapi.io",
          "tonapiTestnetHost": "https://testnet.tonapi.io",
          "tonApiV2Key": "AF77F5JNEUSNXPQAAAAMDXXG7RBQ3IRP6PC2HTHL4KYRWMZYOUQGDEKYFDKBETZ6FDVZJBI",
        }
        """
        
        let decoder = JSONDecoder()
        XCTAssertNoThrow(try decoder.decode(RemoteConfiguration.self, from: configurationResponseString.data(using: .utf8)!))
    }
}
