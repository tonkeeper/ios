@testable import TKUIKit
import UIKit
import XCTest

/// A source inside a scroll view whose top 100pt sit under a top bar and bottom 90pt under a tab bar,
/// so the user sees y 100...754 of the 844pt window.
@MainActor
final class HintClippedSourceTests: XCTestCase {
    private var window: UIWindow!
    private var screenViewController: UIViewController!
    private var scrollView: BarCoveredScrollView!
    private var sourceView: UIView!
    private var tracker: HintContentLayoutTracker!

    override func setUp() {
        super.setUp()
        window = UnsafeAreaFreeWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        screenViewController = UIViewController()
        window.rootViewController = screenViewController
        window.isHidden = false

        scrollView = BarCoveredScrollView(frame: window.bounds)
        scrollView.barInsets = UIEdgeInsets(top: 100, left: 0, bottom: 90, right: 0)
        scrollView.contentSize = CGSize(width: 390, height: 2000)
        screenViewController.view.addSubview(scrollView)

        sourceView = UIView(frame: CGRect(x: 16, y: 1200, width: 120, height: 48))
        scrollView.addSubview(sourceView)

        tracker = HintContentLayoutTracker()
    }

    override func tearDown() {
        tracker.reset()
        tracker = nil
        sourceView = nil
        scrollView = nil
        screenViewController = nil
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    func testSourceBelowTheVisibleAreaIsPointedAtDownFromTheBottomEdge() {
        let (frame, position) = resolveLayout(direction: .bottomRight)

        XCTAssertEqual(position.direction, .topRight)
        XCTAssertEqual(frame.maxY, 753)
        XCTAssertEqual(tailX(of: frame, at: position), sourceView.frame.midX)
    }

    func testSourceAboveTheVisibleAreaIsPointedAtUpFromTheTopEdge() {
        scrollView.contentOffset.y = 1300

        let (frame, position) = resolveLayout(direction: .topRight)

        XCTAssertEqual(position.direction, .bottomRight)
        XCTAssertEqual(frame.minY, 101)
        XCTAssertEqual(tailX(of: frame, at: position), sourceView.frame.midX)
    }

    func testPartlyHiddenSourceIsPointedAtFromItsVisibleSide() {
        scrollView.contentOffset.y = 470

        let (frame, position) = resolveLayout(direction: .bottomRight)

        XCTAssertEqual(position.direction, .topRight)
        XCTAssertEqual(frame.maxY, 730)
    }

    func testVisibleSourceKeepsTheConfiguredDirection() {
        scrollView.contentOffset.y = 800

        let (frame, position) = resolveLayout(direction: .bottomRight)

        XCTAssertEqual(position.direction, .bottomRight)
        XCTAssertEqual(frame.minY, 448)
    }

    /// A card scrolled off to the right of a carousel that is itself below the fold: the hint stays on screen
    /// at the bottom edge, its tail as far right as the tail offset allows.
    func testSourceInANestedScrollViewIsClampedIntoEveryContainer() throws {
        let carousel = UIScrollView(frame: CGRect(x: 0, y: 1200, width: 390, height: 120))
        carousel.contentSize = CGSize(width: 700, height: 120)
        scrollView.addSubview(carousel)
        let card = UIView(frame: CGRect(x: 500, y: 10, width: 100, height: 100))
        carousel.addSubview(card)
        let tailOffset = try XCTUnwrap(TKTooltipView.tailParameters).horizontalOffset

        let (frame, position) = resolveLayout(sourceView: card, direction: .topRight)

        XCTAssertEqual(position.direction, .topLeft)
        XCTAssertEqual(frame.maxY, 753)
        XCTAssertEqual(tailX(of: frame, at: position), window.bounds.maxX - tailOffset)
        XCTAssertTrue(window.bounds.contains(frame))
    }

    func testVisibleFrameIsThePartNotUnderTheBars() {
        XCTAssertNil(sourceView.hintVisibleFrame(in: window))

        scrollView.contentOffset.y = 470

        XCTAssertEqual(sourceView.hintVisibleFrame(in: window), CGRect(x: 16, y: 730, width: 120, height: 24))
    }

    func testScrolledOutSourceIsReachableWhileItsScreenIsOnTop() {
        XCTAssertTrue(sourceView.isReachableByUser)

        window.addSubview(UIView(frame: window.bounds))

        XCTAssertFalse(sourceView.isReachableByUser)
    }

    func testSourceTheUserCannotScrollToIsNotReachable() {
        scrollView.isScrollEnabled = false
        XCTAssertFalse(sourceView.isReachableByUser)

        scrollView.isScrollEnabled = true
        scrollView.contentSize = CGSize(width: 390, height: 900)
        XCTAssertFalse(sourceView.isReachableByUser)
    }

    func testScrollingToTheTopPutsTheViewAtTheTopOfTheVisibleArea() {
        let moves = sourceView.topAligningMoves()

        XCTAssertEqual(moves.map(\.contentOffset), [CGPoint(x: 0, y: 1100)])
        scrollView.contentOffset = CGPoint(x: 0, y: 1100)
        XCTAssertEqual(sourceView.hintVisibleFrame(in: window)?.minY, 100)
    }

    /// Too little content below the view to fill the visible area: it stops as high as the content allows.
    func testScrollingToTheTopStopsWhereTheContentEnds() {
        scrollView.contentSize = CGSize(width: 390, height: 1400)

        XCTAssertEqual(sourceView.topAligningMoves().map(\.contentOffset), [CGPoint(x: 0, y: 646)])
    }

    /// The carousel scrolls the card in from the side, the page scrolls the carousel up to the top.
    func testScrollingToTheTopMovesEveryEnclosingScrollView() {
        let carousel = UIScrollView(frame: CGRect(x: 0, y: 1200, width: 390, height: 120))
        carousel.contentSize = CGSize(width: 700, height: 120)
        scrollView.addSubview(carousel)
        let card = UIView(frame: CGRect(x: 500, y: 10, width: 100, height: 100))
        carousel.addSubview(card)

        let moves = card.topAligningMoves()

        XCTAssertEqual(moves.map(\.contentOffset), [CGPoint(x: 210, y: 0), CGPoint(x: 0, y: 1110)])
        XCTAssertTrue(moves.first?.scrollView === carousel)
    }

    func testTouchesAroundAHintPointingAcrossAnEdgeReachTheScrollView() async {
        showHint()

        XCTAssertTrue(window.hitTest(CGPoint(x: 200, y: 300), with: nil)?.isDescendant(of: scrollView) == true)
        await HintController.dismiss()
    }

    func testTouchesAroundAHintOnAVisibleSourceStayWithTheHint() async {
        scrollView.contentOffset.y = 800
        showHint()

        XCTAssertFalse(window.hitTest(CGPoint(x: 200, y: 300), with: nil)?.isDescendant(of: scrollView) == true)
        await HintController.dismiss()
    }

    func testTailFlipsOnlyWhenTheSourceLeavesThroughTheOtherEdge() {
        let containerView = UIView(frame: window.bounds)
        window.addSubview(containerView)
        let contentViewController = UIViewController()
        contentViewController.preferredContentSize = CGSize(width: 280, height: 40)
        containerView.addSubview(contentViewController.view)
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
        var flips = [HintPosition.Direction]()
        tracker.onPositionFlip = { position, _ in flips.append(position.direction) }
        let (frame, position) = resolveLayout(direction: .topRight)
        tracker.install(
            contentViewController: contentViewController,
            in: containerView,
            sourceView: sourceView,
            sourceWindow: window,
            configuration: configuration(direction: .topRight),
            resolvedPosition: position,
            initialFrame: frame
        )

        scrollView.contentOffset.y = 1300
        tracker.updateTrackedHintPosition()
        scrollView.contentOffset.y = 800
        tracker.updateTrackedHintPosition()
        containerView.layoutIfNeeded()

        XCTAssertEqual(flips, [.bottomRight])
        XCTAssertEqual(contentViewController.view.frame.minY, 448)
    }
}

/// Pins the insets so the geometry does not depend on the device that hosts the suite.
private final class UnsafeAreaFreeWindow: UIWindow {
    override var safeAreaInsets: UIEdgeInsets {
        .zero
    }
}

private final class BarCoveredScrollView: UIScrollView {
    var barInsets = UIEdgeInsets.zero

    override var safeAreaInsets: UIEdgeInsets {
        barInsets
    }

    override var adjustedContentInset: UIEdgeInsets {
        barInsets
    }
}

private extension HintClippedSourceTests {
    func configuration(direction: HintPosition.Direction) -> HintConfiguration {
        HintConfiguration(
            position: HintPosition(
                tailParameters: TKTooltipView.tailParameters,
                horizontal: .default,
                vertical: .init(absolute: 0),
                direction: direction
            ),
            maximumWidth: 280,
            animationStyle: .bouncing
        )
    }

    func resolveLayout(
        sourceView: UIView? = nil,
        direction: HintPosition.Direction
    ) -> (frame: CGRect, position: HintPosition) {
        let contentViewController = UIViewController()
        contentViewController.preferredContentSize = CGSize(width: 280, height: 40)
        return tracker.resolveLayout(
            sourceView: sourceView ?? self.sourceView,
            sourceWindow: window,
            configuration: configuration(direction: direction),
            contentViewController: contentViewController
        )
    }

    func tailX(of frame: CGRect, at position: HintPosition) -> CGFloat {
        frame.minX + position.tailAnchorPoint(in: frame.size).x
    }

    func showHint() {
        HintController.show(
            sourceView: sourceView,
            configuration: configuration(direction: .topRight),
            contentViewControllerProvider: { _ in
                let contentViewController = UIViewController()
                contentViewController.preferredContentSize = CGSize(width: 280, height: 40)
                return contentViewController
            }
        )
    }
}
