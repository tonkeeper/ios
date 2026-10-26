@testable import MoonPay
import XCTest

final class HexEncodingTests: XCTestCase {
    func testDecodesLowerUpperAndPrefixed() {
        XCTAssertEqual(HexEncoding.decode("00ff10"), Data([0x00, 0xFF, 0x10]))
        XCTAssertEqual(HexEncoding.decode("00FF10"), Data([0x00, 0xFF, 0x10]))
        XCTAssertEqual(HexEncoding.decode("0x00ff"), Data([0x00, 0xFF]))
        XCTAssertEqual(HexEncoding.decode("0X00ff"), Data([0x00, 0xFF]))
        XCTAssertEqual(HexEncoding.decode(""), Data())
    }

    func testRejectsMalformedInput() {
        XCTAssertNil(HexEncoding.decode("abc"))
        XCTAssertNil(HexEncoding.decode("zz"))
        XCTAssertNil(HexEncoding.decode("+f"))
        XCTAssertNil(HexEncoding.decode("-1"))
        XCTAssertNil(HexEncoding.decode(" ff"))
        XCTAssertNil(HexEncoding.decode("ff "))
        XCTAssertNil(HexEncoding.decode("0x"))
    }

    func testEncodeRoundTrip() {
        let data = Data((0 ... 255).map { UInt8($0) })
        let hex = HexEncoding.encode(data)
        XCTAssertEqual(hex.count, 512)
        XCTAssertEqual(HexEncoding.decode(hex), data)
        XCTAssertEqual(HexEncoding.encode(Data([0x0A, 0xB0])), "0ab0")
    }
}
