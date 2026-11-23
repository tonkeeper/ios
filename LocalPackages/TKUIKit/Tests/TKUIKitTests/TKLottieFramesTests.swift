@testable import TKUIKit
import XCTest

@MainActor
final class TKLottieFramesTests: XCTestCase {
    func test_framesDrawnOutOfOrderMatchTheOnesDrawnInOrder() throws {
        let inOrder = try makeFrames()
        let outOfOrder = try makeFrames()
        inOrder.renderAll()

        // The last frame first, as the header of a favorited asset draws it, then jumps both ways.
        let last = outOfOrder.count - 1
        let order = [last]
            + (0 ..< last).filter { $0.isMultiple(of: 2) }
            + (0 ..< last).filter { !$0.isMultiple(of: 2) }.reversed()
        XCTAssertEqual(order.sorted(), Array(0 ... last))
        for index in order {
            XCTAssertEqual(outOfOrder.image(at: index).pngData(), inOrder.image(at: index).pngData(), "frame \(index)")
        }
    }

    func test_everyFrameIsStillShownOnceAllAreDrawn() throws {
        let frames = try makeFrames()
        let drawn = (0 ..< frames.count).map { frames.image(at: $0).pngData() }

        for index in 0 ..< frames.count {
            let image = frames.image(at: index)
            XCTAssertEqual(image.size, CGSize(width: 44, height: 44), "frame \(index)")
            XCTAssertEqual(image.pngData(), drawn[index], "frame \(index)")
        }
    }
}

private extension TKLottieFramesTests {
    func makeFrames() throws -> TKLottieFrames {
        try XCTUnwrap(TKLottieFrames(
            .favorite,
            size: CGSize(width: 44, height: 44),
            contentSize: CGSize(width: 56, height: 56),
            scale: 3,
            colors: .original
        ))
    }
}
