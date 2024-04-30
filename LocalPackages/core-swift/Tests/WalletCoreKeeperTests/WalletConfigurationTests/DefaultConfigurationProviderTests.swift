//
//  DefaultConfigurationProviderTests.swift
//  
//
//  Created by Grigory on 20.6.23..
//

import XCTest
@testable import WalletCoreKeeper

final class DefaultConfigurationProviderTests: XCTestCase {

    func testConfigurationProviderLoadsConfigurationFromDiskCorrect() throws {
        let provider = DefaultConfigurationProvider(
            defaultConfigurationFileName: .defaultConfigurationFileName,
            bundle: Bundle.module
        )
        XCTAssertNoThrow(try provider.configuration)
        let configuration = try provider.configuration
        
        XCTAssertEqual(configuration.tonapiV2Endpoint, "https://unit-test.tonapi.io")
        XCTAssertEqual(configuration.tonapiTestnetHost, "https:/unit-test.testnet.tonapi.io")
    }
    
    func testConfigurationProviderThrowErrorIfCantLoadConfigurationFromDisk() throws {
        let provider = DefaultConfigurationProvider(
            defaultConfigurationFileName: "incorrectfilename",
            bundle: Bundle.module
        )
        
        XCTAssertThrowsError(try provider.configuration, "", { error in
            XCTAssertEqual(error as! DefaultConfigurationProvider.Error, DefaultConfigurationProvider.Error.noDefaultConfigurationInBundle)
        })
    }
    
    func testConfigurationProviderThrowErrorIfCantParseConfigurationFile() throws {
        let provider = DefaultConfigurationProvider(
            defaultConfigurationFileName: .corruptedDefaultConfiguration,
            bundle: Bundle.module
        )
        
        XCTAssertThrowsError(try provider.configuration, "", { error in
            XCTAssertEqual(error as! DefaultConfigurationProvider.Error, DefaultConfigurationProvider.Error.defaultConfigurationCorrupted)
        })
    }
}

private extension String {
    static let defaultConfigurationFileName = "TestsDefaultConfiguration.json"
    static let corruptedDefaultConfiguration = "CorruptedDefaultConfiguration.json"
}
