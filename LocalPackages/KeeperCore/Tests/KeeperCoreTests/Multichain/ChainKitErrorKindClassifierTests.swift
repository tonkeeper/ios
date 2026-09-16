import ChainKit
@testable import KeeperCore
import XCTest

/// `kind` is the only part of a multichain failure that reaches the logs, so a node-level error
/// hidden inside `ChainError.Unknown` used to be indistinguishable from a genuine chain error.
final class ChainKitErrorKindClassifierTests: XCTestCase {
    func test_chainError_classifiesAKnownChainError() {
        let kind = ChainKitErrorKindClassifier.kind(chainError: ChainError.BitcoinDustError(message: "dust"))

        XCTAssertEqual(kind, .dustAmount)
    }

    func test_chainError_classifiesARejectedTokenAsUnauthorizedInsteadOfUnknown() {
        let kind = ChainKitErrorKindClassifier.kind(
            chainError: ChainError.Unknown(cause: NodeError.Unauthorized())
        )

        XCTAssertEqual(kind, .unauthorized)
    }

    func test_chainError_classifiesADroppedConnectionAsNetworkError() {
        let kind = ChainKitErrorKindClassifier.kind(
            chainError: ChainError.Unknown(cause: NodeError.NetworkWrap(value: KotlinThrowable(message: "offline")))
        )

        XCTAssertEqual(kind, .networkError)
    }

    func test_chainError_unwrapsANestedChainError() {
        let kind = ChainKitErrorKindClassifier.kind(
            chainError: ChainError.Unknown(cause: ChainError.UtxoError(message: "no utxo"))
        )

        XCTAssertEqual(kind, .utxoError)
    }

    func test_chainError_staysUnknownWhenThereIsNothingToUnwrap() {
        let kind = ChainKitErrorKindClassifier.kind(chainError: ChainError.Unknown(cause: nil))

        XCTAssertEqual(kind, .unknown)
    }
}
