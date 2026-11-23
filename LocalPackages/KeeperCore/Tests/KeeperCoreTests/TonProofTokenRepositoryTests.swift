@testable import KeeperCore
import XCTest

final class TonProofTokenRepositoryTests: XCTestCase {
    func test_deletionCleanupRemovesOnlyTheTokenSavedByThatRefresh() throws {
        let repository = TonProofTokenRepository(keychainVault: InMemoryKeychainVault())
        let wallet = try migrationWallet()
        try repository.saveTonProofToken(wallet: wallet, token: "old-refresh")
        try repository.saveTonProofToken(wallet: wallet, token: "new-refresh")

        try repository.removeTonProofToken(wallet: wallet, ifMatching: "old-refresh")

        XCTAssertEqual(try repository.getTonProofToken(wallet: wallet), "new-refresh")

        try repository.removeTonProofToken(wallet: wallet, ifMatching: "new-refresh")

        XCTAssertThrowsError(try repository.getTonProofToken(wallet: wallet))
        XCTAssertNoThrow(try repository.removeTonProofToken(wallet: wallet, ifMatching: "new-refresh"))
    }
}
