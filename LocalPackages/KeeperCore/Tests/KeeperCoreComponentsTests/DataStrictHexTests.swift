import Foundation
import KeeperCoreComponents
import XCTest

final class DataStrictHexTests: XCTestCase {
    /// Kept identical to `DataHexTests` in the TronSwift package, which carries the other copy of
    /// this decoder — see the note on `Data.init?(strictHex:)`. A behavioural divergence between
    /// the two fails here.
    private static let vectors: [(input: String, expected: Data?)] = [
        ("", Data()),
        ("0x", Data()),
        ("0abc", Data([0x0A, 0xBC])),
        ("0x0abc", Data([0x0A, 0xBC])),
        ("0ABC", Data([0x0A, 0xBC])),
        ("abc", nil),
        ("0xabc", nil),
        ("abcde", nil),
        ("zz", nil),
        ("00zz00", nil),
    ]

    func test_decodesStrictly() {
        for vector in Self.vectors {
            XCTAssertEqual(
                Data(strictHex: vector.input),
                vector.expected,
                "input: \(vector.input)"
            )
        }
    }
}
