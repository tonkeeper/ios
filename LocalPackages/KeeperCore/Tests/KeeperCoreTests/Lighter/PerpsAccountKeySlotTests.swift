@preconcurrency import ChainKit
import Foundation
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsAccountKeySlotTests: XCTestCase {
    private let ownKey = "0x" + String(repeating: "ab", count: 40)
    private let foreignKey = "0x" + String(repeating: "cd", count: 40)

    func testOnlyThisWalletsKeyInItsSlotCountsAsRegistered() async throws {
        let cases: [([Components.Schemas.AccountAPIKey]?, Bool?)] = [
            ([.init(api_key_index: 3, public_key: ownKey.uppercased())], true),
            ([.init(api_key_index: 0, public_key: ownKey)], false),
            ([.init(api_key_index: 3, public_key: foreignKey)], false),
            ([], false),
            (nil, true),
        ]

        for (keys, expected) in cases {
            let delegate = PerpsTkAccountDelegate(
                walletId: "perps-multichain-wallet",
                api: AccountStubAPI(account: .init(account_index: 747_112, has_l2_key: true, api_keys: keys)),
                apiKeyIndex: 3,
                expectedPublicKey: ownKey
            )
            let state: PerpsAccountState = try await bridgeKotlin { delegate.accountState(completionHandler: $0) }
            XCTAssertEqual(state.hasL2Key?.boolValue, expected, "\(String(describing: keys))")
        }
    }
}
