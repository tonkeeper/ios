@testable import LedgerKit
import XCTest

final class LedgerFramingTests: XCTestCase {
    func testFirstFrameCarriesLengthAndNextFramesOnlyIndex() {
        let apdu = Data((0 ..< 300).map { UInt8($0 & 0xFF) })

        let frames = LedgerFraming.frames(of: apdu, frameSize: 153)

        XCTAssertEqual(frames.map(\.count), [153, 153, 5])
        XCTAssertEqual(Array(frames[0].prefix(5)), [0x05, 0x00, 0x00, 0x01, 0x2C])
        XCTAssertEqual(Array(frames[1].prefix(3)), [0x05, 0x00, 0x01])
        XCTAssertEqual(Array(frames[2]), [0x05, 0x00, 0x02, 0x2A, 0x2B])
    }

    func testShortApduFitsOneFrame() {
        let apdu = Data([0xB0, 0x01, 0x00, 0x00, 0x00])

        XCTAssertEqual(LedgerFraming.frames(of: apdu, frameSize: 20), [Data([0x05, 0x00, 0x00, 0x00, 0x05]) + apdu])
    }

    func testAssemblyRebuildsFramedResponse() throws {
        let response = Data((0 ..< 200).map { UInt8(255 - $0) }) + Data([0x90, 0x00])

        let assembly = try LedgerFraming.frames(of: response, frameSize: 64)
            .reduce(LedgerFrameAssembly.empty) { try $0.appending($1) }

        XCTAssertEqual(assembly.response, response)
    }

    func testAssemblyWaitsForTheLastFrame() throws {
        let frames = LedgerFraming.frames(of: Data(repeating: 0xAB, count: 40), frameSize: 20)

        let assembly = try LedgerFrameAssembly.empty.appending(frames[0])

        XCTAssertNil(assembly.response)
    }

    func testAssemblyRejectsFrameOutOfOrder() throws {
        let frames = LedgerFraming.frames(of: Data(repeating: 0xAB, count: 60), frameSize: 20)
        let assembly = try LedgerFrameAssembly.empty.appending(frames[0])

        XCTAssertThrowsError(try assembly.appending(frames[2]))
        XCTAssertThrowsError(try LedgerFrameAssembly.empty.appending(frames[1]))
    }

    func testAssemblyRejectsForeignTag() {
        XCTAssertThrowsError(try LedgerFrameAssembly.empty.appending(Data([0x08, 0x00, 0x00, 0x00, 0x01])))
    }

    func testFrameSizeComesFromMtuReply() {
        XCTAssertEqual(LedgerFraming.frameSize(mtuReply: Data([0x08, 0x00, 0x00, 0x00, 0x01, 0x99])), 153)
        XCTAssertNil(LedgerFraming.frameSize(mtuReply: Data([0x08, 0x00, 0x00, 0x00, 0x01, 0x05])))
        XCTAssertNil(LedgerFraming.frameSize(mtuReply: Data([0x05, 0x00, 0x00, 0x00, 0x01, 0x99])))
    }
}
