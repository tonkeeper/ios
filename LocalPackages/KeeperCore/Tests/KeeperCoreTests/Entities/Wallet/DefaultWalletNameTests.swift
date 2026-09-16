@testable import KeeperCore
import XCTest

final class DefaultWalletNameTests: XCTestCase {
    func test_suggest_returnsBase_whenNoWalletsExist() {
        XCTAssertEqual(suggest(existing: []), "Wallet")
    }

    func test_suggest_returnsBase_whenOnlyCustomNamesExist() {
        XCTAssertEqual(suggest(existing: ["Savings", "Trading 2", "My Wallet 3"]), "Wallet")
    }

    func test_suggest_returnsSecondIndex_whenBaseIsTaken() {
        XCTAssertEqual(suggest(existing: ["Wallet"]), "Wallet 2")
    }

    func test_suggest_continuesFromHighestIndex() {
        XCTAssertEqual(suggest(existing: ["Wallet", "Wallet 2", "Wallet 3"]), "Wallet 4")
    }

    func test_suggest_doesNotReuseFreedIndexes() {
        XCTAssertEqual(suggest(existing: ["Wallet", "Wallet 5"]), "Wallet 6")
        XCTAssertEqual(suggest(existing: ["Wallet 4"]), "Wallet 5")
    }

    func test_suggest_ignoresCaseAndSurroundingWhitespace() {
        XCTAssertEqual(suggest(existing: [" wallet ", "WALLET 2"]), "Wallet 3")
    }

    func test_suggest_ignoresLabelsWithNonIndexSuffix() {
        XCTAssertEqual(suggest(existing: ["Wallet v4R2", "Wallet 2x", "Wallet 1.5", "Wallet 007"]), "Wallet")
    }
}

private extension DefaultWalletNameTests {
    func suggest(existing: [String]) -> String {
        DefaultWalletName.suggest(base: "Wallet", existingLabels: existing)
    }
}
