@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class HintPositionResolutionTests: XCTestCase {
    private var window: UIWindow!
    private var tracker: HintContentLayoutTracker!

    override func setUp() {
        super.setUp()
        window = FixedSafeAreaWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 932))
        window.isHidden = false
        tracker = HintContentLayoutTracker()
    }

    override func tearDown() {
        tracker.reset()
        tracker = nil
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    /// A tab bar item sits in the middle of the screen, so no corner variant of a 280pt
    /// wide hint fits — the tail still has to end up over the item, not next to it.
    func testTailPointsAtASourceTooCenteredForAnyCornerVariant() {
        let sourceView = addSourceView(frame: CGRect(x: 146.5, y: 876, width: 137, height: 48))
        let (frame, position) = resolveLayout()

        XCTAssertEqual(tailX(of: frame, at: position), sourceView.frame.midX)
        XCTAssertTrue(window.bounds.contains(frame))
    }

    func testConfiguredCornerIsKeptWhenItFits() {
        let sourceView = addSourceView(frame: CGRect(x: 60, y: 100, width: 32, height: 32))
        let (frame, position) = resolveLayout()

        XCTAssertEqual(position.direction, .topRight)
        XCTAssertEqual(tailX(of: frame, at: position), sourceView.frame.midX)
    }
}

/// A window reports the safe area of whatever device hosts the suite, and the resolution insets
/// the available bounds by it — a `topRight` hint 60pt from the top fits an iPhone 17e and not an
/// iPhone 17 Pro. Pinning the insets keeps the geometry these frames are written for.
private final class FixedSafeAreaWindow: UIWindow {
    override var safeAreaInsets: UIEdgeInsets {
        .zero
    }
}

private extension HintPositionResolutionTests {
    func addSourceView(frame: CGRect) -> UIView {
        let sourceView = UIView(frame: frame)
        window.addSubview(sourceView)
        return sourceView
    }

    func resolveLayout() -> (frame: CGRect, position: HintPosition) {
        guard let sourceView = window.subviews.last else {
            fatalError("a source view is required")
        }
        let contentViewController = UIViewController()
        contentViewController.preferredContentSize = CGSize(width: 280, height: 40)

        return tracker.resolveLayout(
            sourceView: sourceView,
            sourceWindow: window,
            configuration: HintConfiguration(
                position: HintPosition(
                    tailParameters: TKTooltipView.tailParameters,
                    horizontal: .default,
                    vertical: .init(absolute: 0),
                    direction: .topRight
                ),
                maximumWidth: 280,
                animationStyle: .bouncing
            ),
            contentViewController: contentViewController
        )
    }

    func tailX(of frame: CGRect, at position: HintPosition) -> CGFloat {
        frame.minX + position.tailAnchorPoint(in: frame.size).x
    }
}
