@testable import TKServices
import TKUIKit
import UIKit
import XCTest

@MainActor
final class TooltipsServiceReachabilityTests: XCTestCase {
    /// The screen under a tooltip's source can be covered while it fades in; the request has to wait it out
    /// instead of staying in the queue until some other tooltip comes along.
    func testRequestForACoveredSourceShowsOnceTheCoverIsGone() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let screenViewController = UIViewController()
        window.rootViewController = screenViewController
        window.isHidden = false
        let sourceView = UIView(frame: CGRect(x: 100, y: 400, width: 80, height: 40))
        screenViewController.view.addSubview(sourceView)
        let cover = UIView(frame: window.bounds)
        window.addSubview(cover)
        let controller = RecordingTooltipController()
        let service = TooltipsServiceImplementation(
            tooltipControllerFactory: SingleTooltipControllerFactory(controller: controller),
            viewControllerFactory: TooltipViewControllerFactoryImplementation()
        )

        service.showTooltipIfNeeded(
            id: .tradeFavorite,
            sourceView: sourceView,
            targetActionViews: [],
            configuration: HintConfiguration(position: .default, animationStyle: .bouncing),
            onTargetAction: nil
        )
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(controller.shownCount, 0)

        cover.removeFromSuperview()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertEqual(controller.shownCount, 1)
        await HintController.dismiss()
        window.isHidden = true
    }

    /// The source passes the check that takes the request off the queue and is covered by the time it is
    /// presented: the request goes back to the queue instead of being dropped.
    func testRequestCoveredBetweenDequeueAndPresentationIsKept() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let screenViewController = UIViewController()
        window.rootViewController = screenViewController
        window.isHidden = false
        let sourceView = UIView(frame: CGRect(x: 100, y: 400, width: 80, height: 40))
        screenViewController.view.addSubview(sourceView)
        window.addSubview(ScriptedCover(frame: window.bounds, letsThrough: [true, false, false]))
        let controller = RecordingTooltipController()
        let service = TooltipsServiceImplementation(
            tooltipControllerFactory: SingleTooltipControllerFactory(controller: controller),
            viewControllerFactory: TooltipViewControllerFactoryImplementation()
        )

        service.showTooltipIfNeeded(
            id: .tradeFavorite,
            sourceView: sourceView,
            targetActionViews: [],
            configuration: HintConfiguration(position: .default, animationStyle: .bouncing),
            onTargetAction: nil
        )
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertEqual(controller.shownCount, 1)
        await HintController.dismiss()
        window.isHidden = true
    }

    /// The user takes the tooltip's target action while its request is being presented and the source
    /// gets covered: the request must not come back once the cover is gone.
    func testTargetActionWhileARequestIsPresentedDropsIt() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let screenViewController = UIViewController()
        window.rootViewController = screenViewController
        window.isHidden = false
        let sourceView = UIView(frame: CGRect(x: 100, y: 400, width: 80, height: 40))
        screenViewController.view.addSubview(sourceView)
        let cover = ScriptedCover(frame: window.bounds, letsThrough: [true, false])
        window.addSubview(cover)
        let controller = RecordingTooltipController()
        let service = TooltipsServiceImplementation(
            tooltipControllerFactory: SingleTooltipControllerFactory(controller: controller),
            viewControllerFactory: TooltipViewControllerFactoryImplementation()
        )
        cover.willAnswerHitTest = { answerIndex in
            guard answerIndex == 1 else { return }
            service.didPerformTooltipTargetAction(id: .tradeFavorite)
        }

        service.showTooltipIfNeeded(
            id: .tradeFavorite,
            sourceView: sourceView,
            targetActionViews: [],
            configuration: HintConfiguration(position: .default, animationStyle: .bouncing),
            onTargetAction: nil
        )
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertEqual(controller.shownCount, 0)
        await HintController.dismiss()
        window.isHidden = true
    }
}

/// Answers one window hit test after another as scripted, then lets every later one through.
private final class ScriptedCover: UIView {
    var willAnswerHitTest: ((_ answerIndex: Int) -> Void)?
    private var letsThrough: [Bool]
    private var answerCount = 0

    init(frame: CGRect, letsThrough: [Bool]) {
        self.letsThrough = letsThrough
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        willAnswerHitTest?(answerCount)
        answerCount += 1
        guard !letsThrough.isEmpty else {
            return nil
        }
        return letsThrough.removeFirst() ? nil : self
    }
}

private final class RecordingTooltipController: TooltipController {
    private(set) var shownCount = 0

    var canShowTooltip: Bool {
        true
    }

    func didShowTooltip() {
        shownCount += 1
    }

    func didPerformTargetAction() {}

    func didDismiss() {}
}

private struct SingleTooltipControllerFactory: TooltipControllerFactory {
    let controller: TooltipController

    func controller(for tooltipId: TooltipID) -> TooltipController {
        controller
    }
}
