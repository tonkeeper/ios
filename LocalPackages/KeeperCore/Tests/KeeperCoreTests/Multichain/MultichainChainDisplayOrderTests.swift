@testable import KeeperCore
import XCTest

final class MultichainChainDisplayOrderTests: XCTestCase {
    func test_displayOrder_listsEveryChainOnce() {
        XCTAssertEqual(MultichainChain.displayOrder.count, MultichainChain.allCases.count)
        XCTAssertEqual(Set(MultichainChain.displayOrder), Set(MultichainChain.allCases))
    }

    func test_orderedByDisplayOrder_sortsAndDropsDuplicates() {
        XCTAssertEqual(
            MultichainChain.orderedByDisplayOrder([.base, .ton, .btc, .ton, .bsc, .eth]),
            [.ton, .eth, .bsc, .btc, .base]
        )
    }
}
