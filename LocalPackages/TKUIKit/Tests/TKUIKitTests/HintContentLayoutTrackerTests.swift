@testable import TKUIKit
import UIKit
import XCTest

private final class FixedSizeContentViewController: UIViewController {
    init(size: CGSize) {
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = size
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
final class HintContentLayoutTrackerTests: XCTestCase {
    private var window: UIWindow!
    private var header: UIView!
    private var sourceView: UIView!
    private var containerView: UIView!
    private var contentViewController: FixedSizeContentViewController!
    private var tracker: HintContentLayoutTracker!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false

        header = UIView(frame: CGRect(x: 0, y: 60, width: 390, height: 60))
        window.addSubview(header)
        sourceView = UIView(frame: CGRect(x: 100, y: 8, width: 32, height: 32))
        header.addSubview(sourceView)

        containerView = UIView(frame: window.bounds)
        window.addSubview(containerView)

        contentViewController = FixedSizeContentViewController(size: CGSize(width: 240, height: 56))
        containerView.addSubview(contentViewController.view)
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = false

        tracker = HintContentLayoutTracker()
    }

    override func tearDown() {
        tracker.reset()
        tracker = nil
        contentViewController = nil
        containerView = nil
        sourceView = nil
        header = nil
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    func testContentFollowsTheSourceViewWhileItStaysInTheWindow() {
        install()
        let installedFrame = contentViewController.view.frame

        header.frame.origin.y += 40
        tracker.updateTrackedHintPosition()
        containerView.layoutIfNeeded()

        XCTAssertEqual(contentViewController.view.frame, installedFrame.offsetBy(dx: 0, dy: 40))
    }

    /// A detached source view has no meaningful window-space frame, so following it would
    /// teleport the hint into the top-left corner instead of keeping it on its anchor.
    func testContentStaysPutWhenTheSourceViewLeavesTheWindow() {
        var lostCount = 0
        tracker.onSourceViewLost = { lostCount += 1 }
        install()
        let installedFrame = contentViewController.view.frame

        header.removeFromSuperview()
        header.frame.origin.y += 200
        tracker.updateTrackedHintPosition()
        containerView.layoutIfNeeded()

        XCTAssertEqual(lostCount, 1)
        XCTAssertEqual(contentViewController.view.frame, installedFrame)
    }
}

private extension HintContentLayoutTrackerTests {
    var configuration: HintConfiguration {
        HintConfiguration(
            position: HintPosition(
                tailParameters: nil,
                horizontal: .default,
                vertical: HintPosition.VerticalPosition(absolute: 4),
                direction: .topRight
            ),
            maximumWidth: 240,
            animationStyle: .bouncing
        )
    }

    func install() {
        let (frame, position) = tracker.resolveLayout(
            sourceView: sourceView,
            sourceWindow: window,
            configuration: configuration,
            contentViewController: contentViewController
        )
        tracker.install(
            contentViewController: contentViewController,
            in: containerView,
            sourceView: sourceView,
            sourceWindow: window,
            configuration: configuration,
            resolvedPosition: position,
            initialFrame: frame
        )
        containerView.layoutIfNeeded()
    }
}
