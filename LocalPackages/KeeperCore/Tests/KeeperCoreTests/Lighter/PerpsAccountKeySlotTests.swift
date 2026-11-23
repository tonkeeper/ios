@preconcurrency import ChainKit
import Foundation
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

final class PerpsAccountKeySlotTests: XCTestCase {
    private let ownKey = "0x" + String(repeating: "ab", count: 40)
    private let foreignKey = "0x" + String(repeating: "cd", count: 40)
    private let ownAddress = "0x7ECebAF27c989adEF9EA3DD06D316F6F463a5109"
    private let foreignAddress = "0x00000000000000000000000000000000000000aa"

    func testOnlyThisWalletsKeyInItsSlotCountsAsRegistered() async throws {
        let cases: [([Components.Schemas.AccountAPIKey]?, Bool?)] = [
            ([.init(api_key_index: 3, public_key: ownKey.uppercased())], true),
            ([.init(api_key_index: 0, public_key: ownKey)], false),
            ([.init(api_key_index: 3, public_key: foreignKey)], false),
            ([], false),
            (nil, true),
        ]

        for (keys, expected) in cases {
            let delegate = makeDelegate(account: .init(account_index: 747_112, l1_address: ownAddress.lowercased(), has_l2_key: true, api_keys: keys))
            let state: PerpsAccountState = try await bridgeKotlin { delegate.accountState(completionHandler: $0) }
            XCTAssertEqual(state.hasL2Key?.boolValue, expected, "\(String(describing: keys))")
        }
    }

    func testAnAccountNotBoundToTheWalletIsNotRegisteredFor() async {
        let accounts: [(String, Components.Schemas.Account)] = [
            ("another address", .init(account_index: 747_112, l1_address: foreignAddress, has_l2_key: true, api_keys: [.init(api_key_index: 3, public_key: ownKey)])),
            ("no address", .init(account_index: 747_112, has_l2_key: true, api_keys: [.init(api_key_index: 3, public_key: ownKey)])),
            ("another address, no account yet", .init(l1_address: foreignAddress)),
        ]

        for (name, account) in accounts {
            let delegate = makeDelegate(account: account)
            do {
                let _: PerpsAccountState = try await bridgeKotlin { delegate.accountState(completionHandler: $0) }
                XCTFail("\(name) was read as the wallet's account")
            } catch {
                XCTAssertEqual(error as? PerpsTradingError, .protocolFailure("account is bound to another address"), name)
            }
        }
    }

    func testAnUnboundWalletReadsAsNoAccount() async throws {
        let delegate = makeDelegate(account: .init())

        let state: PerpsAccountState = try await bridgeKotlin { delegate.accountState(completionHandler: $0) }

        XCTAssertNil(state.accountIndex)
    }

    func testTheConfirmationIsForTheAccountTheKeyWasSignedFor() async throws {
        let delegate = makeDelegate(account: .init(account_index: 747_112, l1_address: ownAddress, has_l2_key: true, api_keys: [.init(api_key_index: 3, public_key: ownKey)]))

        let state: PerpsAccountState = try await bridgeKotlin { delegate.confirmRegistration(registration: registration(accountIndex: 747_112), completionHandler: $0) }

        XCTAssertEqual(state.accountIndex?.int64Value, 747_112)
    }

    func testAConfirmationForAnotherAccountFails() async {
        let confirmations: [(String, Components.Schemas.Account)] = [
            ("another account", .init(account_index: 747_113, l1_address: ownAddress, has_l2_key: true, api_keys: [.init(api_key_index: 3, public_key: ownKey)])),
            ("another address", .init(account_index: 747_112, l1_address: foreignAddress, has_l2_key: true, api_keys: [.init(api_key_index: 3, public_key: ownKey)])),
        ]

        for (name, account) in confirmations {
            let delegate = makeDelegate(account: account)
            do {
                let _: PerpsAccountState = try await bridgeKotlin { delegate.confirmRegistration(registration: registration(accountIndex: 747_112), completionHandler: $0) }
                XCTFail("\(name) confirmed the registration")
            } catch {
                XCTAssertNotNil(error as? PerpsTradingError, name)
            }
        }
    }

    private func makeDelegate(account: Components.Schemas.Account) -> PerpsTkAccountDelegate {
        PerpsTkAccountDelegate(
            walletId: "perps-multichain-wallet",
            api: AccountStubAPI(account: account),
            apiKeyIndex: 3,
            expectedPublicKey: ownKey,
            ownerAddress: ownAddress
        )
    }

    private func registration(accountIndex: Int64) -> PerpsAccountRegistration {
        PerpsAccountRegistration(accountIndex: accountIndex, apiKeyIndex: 3, txType: 8, txInfo: "{}", txHash: "0xhash")
    }
}
