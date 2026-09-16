import SwiftUI
@testable import TKUIKit
import UIKit
import XCTest

/// Reports the height SwiftUI actually laid the content out at.
private final class RenderedHeightRecorder: @unchecked Sendable {
    var height: CGFloat = 0
}

@MainActor
final class TKBottomSheetHostingControllerTests: XCTestCase {
    private var window: UIWindow!
    private var rootViewController: UIViewController!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        rootViewController = UIViewController()
        window.rootViewController = rootViewController
        window.isHidden = false
        rootViewController.view.frame = window.bounds
        rootViewController.view.layoutIfNeeded()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        rootViewController = nil
        super.tearDown()
    }

    func testHeightIsContentHeightPlusBottomSafeAreaInset() {
        rootViewController.additionalSafeAreaInsets.bottom = 34
        let controller = embed(makeController(contentHeight: 200))
        let inset = rootViewController.view.safeAreaInsets.bottom

        XCTAssertGreaterThan(inset, 0, "the test needs a bottom inset to be meaningful")
        XCTAssertEqual(controller.calculateHeight(withWidth: 390), 200 + inset, accuracy: 0.5)
    }

    /// The sheet is presented ignoring the bottom safe area, so the content controller is the one that
    /// has to reserve it — measuring the on-screen view instead would fold it in a second time.
    func testContentIsMeasuredFreeOfTheSafeAreaItReservesFor() {
        let controller = embed(makeController(contentHeight: 200))
        let heightWithoutInset = controller.calculateHeight(withWidth: 390)

        rootViewController.additionalSafeAreaInsets.bottom = 34
        rootViewController.view.layoutIfNeeded()

        XCTAssertEqual(
            controller.calculateHeight(withWidth: 390) - heightWithoutInset,
            34,
            accuracy: 0.5,
            "the inset must be added once, not compounded into the measured content"
        )
    }

    func testSettingContentRemeasuresAndReportsANewHeight() {
        let controller = embed(makeController(contentHeight: 200))
        var heightUpdates = 0
        controller.didUpdateHeight = { heightUpdates += 1 }

        controller.setContent(fixedHeightContent(300))

        XCTAssertEqual(heightUpdates, 1)
        XCTAssertEqual(
            controller.calculateHeight(withWidth: 390),
            300 + rootViewController.view.safeAreaInsets.bottom,
            accuracy: 0.5
        )
    }

    /// The sheet hands the content controller a frame that is taller than the content — it reserves
    /// the bottom safe area, and grows further while the sheet is dragged up. A hosting controller
    /// centers a root view that does not fill its bounds, so the content has to be pinned itself.
    func testContentIsPinnedToTheTopOfATallerFrame() {
        let controller = embed(
            TKBottomSheetHostingController(
                content: AnyView(
                    Color.red
                        .frame(height: 100)
                )
            )
        )
        // Away from the window edges, so no safe-area inset applies — the sheet places its content
        // controller mid-screen too.
        controller.view.frame = CGRect(x: 0, y: 400, width: 200, height: 300)
        controller.view.layoutIfNeeded()

        XCTAssertTrue(
            isRed(controller.view, at: CGPoint(x: 100, y: 10)),
            "content must start at the top of the frame"
        )
        XCTAssertFalse(
            isRed(controller.view, at: CGPoint(x: 100, y: 290)),
            "the slack must stay below the content, not be split around it"
        )
    }

    /// The controller measures the bare content but renders it inside `TKBottomSheetContentContainer`.
    /// Text that is free to render fewer lines than the measurement counted makes the two disagree, and
    /// the sheet opens with dead space under the content.
    func testWrappingTextRendersAtTheHeightItWasMeasuredAt() {
        let recorder = RenderedHeightRecorder()
        let controller = embed(TKBottomSheetHostingController(content: wrappingTextContent(recorder)))

        let measured = controller.calculateHeight(withWidth: 390)
        render(controller, width: 390, height: measured)

        let contentHeight = measured - rootViewController.view.safeAreaInsets.bottom
        XCTAssertGreaterThan(contentHeight, 200, "the copy has to wrap for this to test anything")
        XCTAssertEqual(recorder.height, contentHeight, accuracy: 1)
    }

    /// Content taller than the sheet's available height is clamped to it, and the container does not
    /// reflow the content to fit — it keeps its measured height and is clipped. Such content belongs in
    /// a scrollable sheet; this pins the current behaviour rather than endorsing it.
    func testContentClampedToAShorterFrameKeepsItsMeasuredHeight() {
        let recorder = RenderedHeightRecorder()
        let controller = embed(TKBottomSheetHostingController(content: wrappingTextContent(recorder)))

        let measured = controller.calculateHeight(withWidth: 390)
        render(controller, width: 390, height: measured / 2)

        XCTAssertEqual(
            recorder.height,
            measured - rootViewController.view.safeAreaInsets.bottom,
            accuracy: 1
        )
    }

    func testHeaderConfigurationChangeIsReported() {
        let controller = embed(makeController(contentHeight: 200))
        var reportedTitles = [String]()
        controller.didUpdateHeaderConfiguration = { configuration in
            guard case let .title(title, _, _) = configuration?.title else { return }
            reportedTitles.append(title)
        }

        controller.headerConfiguration = TKBottomSheetHeaderConfiguration(
            title: .title(title: "Updated")
        )

        XCTAssertEqual(reportedTitles, ["Updated"])
    }
}

private extension TKBottomSheetHostingControllerTests {
    func makeController(contentHeight: CGFloat) -> TKBottomSheetHostingController<AnyView> {
        TKBottomSheetHostingController(content: fixedHeightContent(contentHeight))
    }

    func fixedHeightContent(_ height: CGFloat) -> AnyView {
        AnyView(
            Color.clear
                .frame(height: height)
        )
    }

    /// The shape sheet popups use: a stack of centered copy that has to wrap at the sheet's width.
    func wrappingTextContent(_ recorder: RenderedHeightRecorder) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                Color.clear
                    .frame(width: 84, height: 84)

                Text("Price impact is too high")
                    .textStyle(.h2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                Text("The difference between the market price and the estimated price due to trade size.")
                    .textStyle(.body1)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                Text("Try reducing the amount you are swapping, or use a pair with deeper liquidity.")
                    .textStyle(.body1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(
                GeometryReader { proxy -> Color in
                    recorder.height = proxy.size.height
                    return Color.clear
                }
            )
        )
    }

    func render(
        _ controller: TKBottomSheetHostingController<AnyView>,
        width: CGFloat,
        height: CGFloat
    ) {
        controller.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    func isRed(_ view: UIView, at point: CGPoint) -> Bool {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("could not create a sampling context")
            return false
        }

        context.translateBy(x: -point.x, y: -point.y)
        view.layer.render(in: context)

        return pixel[0] > 200 && pixel[1] < 80 && pixel[2] < 80
    }

    func embed(
        _ controller: TKBottomSheetHostingController<AnyView>
    ) -> TKBottomSheetHostingController<AnyView> {
        rootViewController.addChild(controller)
        controller.view.frame = rootViewController.view.bounds
        rootViewController.view.addSubview(controller.view)
        controller.didMove(toParent: rootViewController)
        rootViewController.view.layoutIfNeeded()
        return controller
    }
}
