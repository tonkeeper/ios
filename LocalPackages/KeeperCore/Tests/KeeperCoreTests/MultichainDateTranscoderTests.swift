@testable import KeeperCore
import XCTest

final class MultichainDateTranscoderTests: XCTestCase {
    func test_decodesPlainAndFractionalTimestamps() throws {
        let transcoder = MultichainDateTranscoder()

        XCTAssertNotNil(try transcoder.decode("2026-07-31T13:00:00Z"))
        XCTAssertNotNil(try transcoder.decode("2026-07-31T13:00:00.123Z"))
    }

    func test_concurrentDecodingIsStable() throws {
        let transcoder = MultichainDateTranscoder()
        let samples = ["2026-07-31T13:00:00Z", "2026-07-31T13:00:00.123Z"]
        let expected = try samples.map(transcoder.decode)

        DispatchQueue.concurrentPerform(iterations: 1000) { index in
            let sampleIndex = index % samples.count
            XCTAssertEqual(try? transcoder.decode(samples[sampleIndex]), expected[sampleIndex])
        }
    }
}
