import Foundation
import Testing
@testable import TronSwiftAPI

struct DataHexTests {
    /// Kept identical to `DataStrictHexTests` in `KeeperCoreComponents`, which carries the copy of
    /// this decoder for the modules that cannot reach this one — see the note on
    /// `Data.init?(strictHex:)`. A behavioural divergence between the two fails here.
    static let vectors: [(input: String, expected: Data?)] = [
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

    @Test(arguments: DataHexTests.vectors)
    func decodesStrictly(vector: (input: String, expected: Data?)) {
        #expect(Data(strictHex: vector.input) == vector.expected)
    }
}
