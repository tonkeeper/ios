import ChainKit
@testable import KeeperCore
import XCTest

final class PerpsWalletAuthKeyTests: XCTestCase {
    private let mnemonic = """
    abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
    """

    func testDerivingTheWalletAuthKeyTwiceGivesTheSameLiveKey() throws {
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)

        let first = wallet.walletKeyPair(kind: .multichain)
        let firstBytes = first.privateKey.asData
        first.privateKey.fillZeros()
        let second = wallet.walletKeyPair(kind: .multichain)
        let secondBytes = second.privateKey.asData
        second.privateKey.fillZeros()

        XCTAssertFalse(firstBytes.allSatisfy { $0 == 0 })
        XCTAssertEqual(firstBytes, secondBytes)
    }
}
