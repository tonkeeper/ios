//
//  TCUrlParserTests.swift
//  
//
//  Created by Grigory Serebryanyy on 18.10.2023.
//

import XCTest
@testable import WalletCoreKeeper

final class TCUrlParserTests: XCTestCase {

    func testDemoDappWithReactUITCUrlParse() throws {
        let string = """
        tc://?v=2&id=4091db63def30d086acef76cd045a20ca6def5744bad530d2a86766d3e781477&r=%7B%22manifestUrl%22%3A%22https%3A%2F%2Fton-connect.github.io%2Fdemo-dapp-with-react-ui%2Ftonconnect-manifest.json%22%2C%22items%22%3A%5B%7B%22name%22%3A%22ton_addr%22%7D%2C%7B%22name%22%3A%22ton_proof%22%2C%22payload%22%3A%224c9523d2c0017c3e00000000652fc398090082a031a65ab99be6209a91c0f818%22%7D%5D%7D
        """
        let parser = TonConnectUrlParser()
        let parameters = try parser.parseString(string)
        
        XCTAssertEqual(parameters.version, .v2)
        XCTAssertEqual(parameters.clientId, "4091db63def30d086acef76cd045a20ca6def5744bad530d2a86766d3e781477")
        XCTAssertEqual(parameters.requestPayload.manifestUrl,
                       URL(string: "https://ton-connect.github.io/demo-dapp-with-react-ui/tonconnect-manifest.json")!)
        XCTAssertEqual(parameters.requestPayload.items,
                       [.tonAddress,
                        .tonProof(payload: "4c9523d2c0017c3e00000000652fc398090082a031a65ab99be6209a91c0f818")])
    }
}

extension TonConnectRequestPayload.Item: Equatable {
    public static func == (lhs: TonConnectRequestPayload.Item, rhs: TonConnectRequestPayload.Item) -> Bool {
        switch (lhs, rhs) {
        case (.tonAddress, .tonAddress): return true
        case (.tonProof(let lpayload), .tonProof(let rpayload)):
            return lpayload == rpayload
        default: return false
        }
    }
}
