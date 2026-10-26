@testable import KeeperCore
import XCTest

final class WalletConnectChainTests: XCTestCase {
    func test_caip2RoundTripsForEveryChain() {
        for chain in WalletConnectChain.allCases {
            XCTAssertEqual(WalletConnectChain(caip2: chain.caip2), chain)
            XCTAssertEqual(chain.caip2Identifiers.first, chain.caip2)
            for identifier in chain.caip2Identifiers {
                XCTAssertEqual(WalletConnectChain(caip2: identifier), chain, identifier)
            }
        }
    }

    func test_solanaAcceptsTheLegacyMainnetIdentifier() {
        XCTAssertEqual(WalletConnectChain(caip2: "solana:4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZ"), .sol)
        XCTAssertEqual(WalletConnectChain(caip2: " solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp\n"), .sol)
    }

    func test_solanaReferenceIsCaseSensitive() {
        XCTAssertNil(WalletConnectChain(caip2: "solana:5eykt4usfv8p8njdtrepy1vzqkqzkvdp"))
        XCTAssertNil(WalletConnectChain(caip2: "SOLANA:5EYKT4USFV8P8NJDTREPY1VZQKQZKVDP"))
    }

    func test_hexAndDecimalReferencesStayCaseInsensitive() {
        XCTAssertEqual(WalletConnectChain(caip2: "TRON:0x2B6653DC"), .tron)
        XCTAssertEqual(WalletConnectChain(caip2: "EIP155:8453"), .base)
    }

    func test_solanaIsNotEVM() {
        XCTAssertNil(WalletConnectChain.sol.eip155ChainId)
        XCTAssertFalse(WalletConnectChain.sol.supportsEip1559Fees)
        XCTAssertEqual(WalletConnectChain.sol.namespace, "solana")
        XCTAssertEqual(WalletConnectChain.sol.multichainChain, .sol)
    }

    func test_solanaMethodsBelongToTheSolanaNamespaceOnly() {
        XCTAssertEqual(WalletConnectMethod.supportedMethods(namespace: "solana"), WalletConnectMethod.solanaMethods)
        XCTAssertEqual(WalletConnectMethod.supportedMethods(chain: .sol), WalletConnectMethod.solanaMethods)
        XCTAssertTrue(WalletConnectMethod.solanaMethods.isDisjoint(with: WalletConnectMethod.evmMethods))
        XCTAssertFalse(WalletConnectMethod.solanaSignMessage.isSupported(chain: .eth))
        XCTAssertFalse(WalletConnectMethod.personalSign.isSupported(chain: .sol))
    }
}
