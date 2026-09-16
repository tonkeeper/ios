@testable import KeeperCore
import TonSwift
import XCTest

final class MultichainWalletTests: XCTestCase {
    func test_decodingMultichainStatePreservesAddressType() throws {
        let json = """
        {
          "multichain": {
            "_0": {
              "walletId": "chainkit-wallet-id",
              "addresses": [
                {
                  "chain": "ton",
                  "address": "UQTonV5",
                  "type": "v5R1"
                },
                {
                  "chain": "btc",
                  "address": "bc1derived",
                  "type": "p2wpkh"
                },
                {
                  "chain": "eth",
                  "address": "0xabc"
                }
              ]
            }
          }
        }
        """

        let wallet = try JSONDecoder().decode(MultichainWallet.self, from: Data(json.utf8))

        guard case let .multichain(state) = wallet else {
            XCTFail("Expected multichain state")
            return
        }
        XCTAssertEqual(
            state.addresses,
            [
                MultichainWalletAddress(chain: .ton, address: "UQTonV5", type: .tonV5R1),
                MultichainWalletAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH),
                MultichainWalletAddress(chain: .eth, address: "0xabc"),
            ]
        )
        XCTAssertTrue(state.addresses.allSatisfy { $0.publicKey == nil })
    }

    func test_decodingMultichainStateRequiresWalletId() throws {
        let json = """
        {
          "multichain": {
            "_0": {
              "walletId": "c557eec878dfd852ba3f88087c4f350f09c55537ab5e549c3cd14320ec3cef38",
              "addresses": [
                {
                  "chain": "eth",
                  "address": "0xabc"
                }
              ]
            }
          }
        }
        """

        let wallet = try JSONDecoder().decode(MultichainWallet.self, from: Data(json.utf8))

        guard case let .multichain(state) = wallet else {
            XCTFail("Expected multichain state")
            return
        }
        XCTAssertEqual(
            state.walletId,
            "c557eec878dfd852ba3f88087c4f350f09c55537ab5e549c3cd14320ec3cef38"
        )
        XCTAssertEqual(
            state.addresses,
            [MultichainWalletAddress(chain: .eth, address: "0xabc")]
        )
    }

    func test_decodingMultichainStateWithoutSyncStateDefaultsToPending() throws {
        let json = """
        {
          "multichain": {
            "_0": {
              "walletId": "chainkit-wallet-id",
              "addresses": [
                {
                  "chain": "eth",
                  "address": "0xabc"
                }
              ]
            }
          }
        }
        """

        let wallet = try JSONDecoder().decode(MultichainWallet.self, from: Data(json.utf8))

        guard case let .multichain(state) = wallet else {
            XCTFail("Expected multichain state")
            return
        }
        XCTAssertEqual(state.syncState, .pending)
    }

    func test_decodingLegacyAddressesStateThrows() {
        let json = """
        {
          "addresses": {
            "_0": [
              {
                "chain": "eth",
                "address": "0xabc"
              }
            ]
          }
        }
        """

        XCTAssertThrowsError(
            try JSONDecoder().decode(MultichainWallet.self, from: Data(json.utf8))
        )
    }

    func test_decodingMultichainStateWithNullWalletIdThrows() {
        let json = """
        {
          "multichain": {
            "_0": {
              "walletId": null,
              "addresses": []
            }
          }
        }
        """

        XCTAssertThrowsError(
            try JSONDecoder().decode(MultichainWallet.self, from: Data(json.utf8))
        )
    }

    func test_preferredMultichainAddressTypeSupportsOnlyTONV4R2AndV5R1() {
        let cases: [(WalletContractVersion, MultichainWalletAddressType)] = [
            (.v3R1, .tonV4R2),
            (.v3R2, .tonV4R2),
            (.v4R1, .tonV4R2),
            (.v4R2, .tonV4R2),
            (.v5Beta, .tonV4R2),
            (.v5R1, .tonV5R1),
        ]

        for (version, expectedType) in cases {
            let wallet = makeWallet(contractVersion: version)

            XCTAssertEqual(wallet.preferredMultichainAddressType(for: .ton), expectedType)
            XCTAssertNil(wallet.preferredMultichainAddressType(for: .eth))
        }
    }

    /// The key carries the storage format of the whole multichain state, so bumping it is how a
    /// state that can no longer be migrated in place is dropped: the wallet decodes as unichain
    /// and enrichment re-derives it from the mnemonic.
    func test_walletUsesMultichainV5AndIgnoresMultichainV4() throws {
        let wallet = makeWallet(
            contractVersion: .v5R1,
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain-wallet",
                    addresses: [
                        .init(chain: .ton, address: "ton-v5", type: .tonV5R1),
                    ]
                )
            )
        )
        let encoded = try JSONEncoder().encode(wallet)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        XCTAssertNotNil(json["multichain_v5"])
        XCTAssertNil(json["multichain_v4"])

        var legacyJSON = json
        legacyJSON["multichain_v4"] = legacyJSON.removeValue(forKey: "multichain_v5")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyJSON)
        let decodedLegacyWallet = try JSONDecoder().decode(Wallet.self, from: legacyData)

        XCTAssertNil(decodedLegacyWallet.multichain)
    }
}

private extension MultichainWalletTests {
    func makeWallet(
        contractVersion: WalletContractVersion,
        multichain: MultichainWallet? = nil
    ) -> Wallet {
        Wallet(
            id: "wallet-\(contractVersion.rawValue)",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: 0x01, count: 32)),
                    contractVersion
                )
            ),
            metaData: WalletMetaData(
                label: "wallet",
                tintColor: .SteelGray,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}
