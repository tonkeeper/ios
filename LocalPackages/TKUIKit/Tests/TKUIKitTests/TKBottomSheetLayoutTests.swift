@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class TKBottomSheetLayoutTests: XCTestCase {
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

    /// The regression behind TK-2800: the sheet measured the header before assigning it a frame, so a
    /// measurement resolved against a zero width opened the sheet with a header hundreds of points too
    /// tall, which then snapped once the content reported its height.
    func testHeaderOpensAtItsSettledHeight() {
        let sheet = startSheet(
            StubContentViewController(
                contentHeight: 200,
                title: .title(
                    title: "Network fee",
                    subtitle: "Choose the method you want to use for paying the network fee of this transfer now"
                )
            )
        )

        let settledHeight = sheet.headerView.systemLayoutSizeFitting(
            CGSize(width: 390, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let singleLineSheet = startSheet(
            StubContentViewController(
                contentHeight: 200,
                title: .title(title: "Network fee", subtitle: "Choose method")
            )
        )
        let singleLineHeight = singleLineSheet.headerView.systemLayoutSizeFitting(
            CGSize(width: 390, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        XCTAssertEqual(sheet.headerView.frame.height, settledHeight, accuracy: 0.5)
        XCTAssertGreaterThan(settledHeight, singleLineHeight, "the subtitle should need more than one line at this width")
        XCTAssertLessThan(sheet.headerView.frame.height, 200, "the header must not blow up to a wrapped-at-zero-width height")
    }

    func testHeaderAndContentStayAdjacentInsideTheContainer() {
        let sheet = startSheet(
            StubContentViewController(
                contentHeight: 200,
                title: .title(title: "Network fee", subtitle: "Choose method")
            )
        )

        XCTAssertEqual(sheet.headerView.frame.minY, 0, accuracy: 0.5)
        XCTAssertEqual(sheet.headerView.frame.width, 390, accuracy: 0.5)
        XCTAssertGreaterThan(sheet.headerView.frame.height, 0)
        XCTAssertEqual(
            sheet.contentViewController.view.frame.minY,
            sheet.headerView.frame.maxY,
            accuracy: 0.5
        )
    }

    /// Content that reports a height from inside the layout pass our own measurement triggers must not
    /// re-enter measurement — the outer, stale layout would be the one left applied.
    func testHeightReportedDuringMeasurementDoesNotReEnterMeasurement() {
        let contentViewController = StubContentViewController(
            contentHeight: 200,
            title: .title(title: "Network fee", subtitle: "Choose method")
        )
        let sheet = startSheet(contentViewController)
        waitForPresentationToFinish(contentViewController)

        let containerHeightBefore = sheet.containerView.frame.height
        contentViewController.notifiesHeightWhileMeasuring = true
        contentViewController.contentHeight = 300
        contentViewController.didUpdateHeight?()

        XCTAssertEqual(contentViewController.maximumMeasurementDepth, 1, "measurement must never nest")
        XCTAssertEqual(
            sheet.containerView.frame.height - containerHeightBefore,
            100,
            accuracy: 0.5,
            "the newest measurement must be the one left applied"
        )
    }

    func testRepeatedHeightReportsSettleOnTheLatestContentHeight() {
        let contentViewController = StubContentViewController(
            contentHeight: 120,
            title: .title(title: "Network fee", subtitle: "Choose method")
        )
        let sheet = startSheet(contentViewController)
        waitForPresentationToFinish(contentViewController)

        let containerHeightBefore = sheet.containerView.frame.height
        for height in [180, 240, 300] as [CGFloat] {
            contentViewController.contentHeight = height
            contentViewController.didUpdateHeight?()
        }

        XCTAssertEqual(
            sheet.containerView.frame.height - containerHeightBefore,
            180,
            accuracy: 0.5,
            "the sheet must end up sized for the latest reported height"
        )
        XCTAssertEqual(contentViewController.maximumMeasurementDepth, 1)
    }

    func testHeaderIsMeasuredOncePerUpdateWhenNothingChanges() {
        let contentViewController = StubContentViewController(
            contentHeight: 200,
            title: .title(title: "Network fee", subtitle: "Choose method")
        )
        let sheet = startSheet(contentViewController)
        waitForPresentationToFinish(contentViewController)

        let measurementsBefore = contentViewController.measurementCount
        contentViewController.didUpdateHeight?()

        XCTAssertEqual(
            contentViewController.measurementCount - measurementsBefore,
            1,
            "a settled sheet must not run an extra measurement pass"
        )
        XCTAssertEqual(sheet.contentViewController.view.frame.height, 200, accuracy: 0.5)
    }
}

private extension TKBottomSheetLayoutTests {
    /// UIKit modal presentation never completes in this test bundle (no window scene), so install the
    /// sheet's view directly and run the same entry point `present(fromViewController:)` uses.
    func startSheet(_ contentViewController: TKBottomSheetContentViewController) -> TKBottomSheetViewController {
        let sheet = TKBottomSheetViewController(contentViewController: contentViewController)
        rootViewController.addChild(sheet)
        sheet.view.frame = rootViewController.view.bounds
        rootViewController.view.addSubview(sheet.view)
        sheet.didMove(toParent: rootViewController)
        sheet.view.layoutIfNeeded()
        sheet.startPresentation()
        return sheet
    }

    /// The sheet defers height updates until the entry animation completes, and the animated frame is
    /// already at its final model value, so wait out the animation and then prove updates land.
    func waitForPresentationToFinish(_ contentViewController: StubContentViewController) {
        RunLoop.current.run(until: Date().addingTimeInterval(1))

        let measurementsBefore = contentViewController.measurementCount
        contentViewController.didUpdateHeight?()
        XCTAssertGreaterThan(
            contentViewController.measurementCount,
            measurementsBefore,
            "the sheet is still deferring height updates"
        )
    }
}

private final class StubContentViewController: UIViewController, TKBottomSheetContentViewController {
    var contentHeight: CGFloat
    var notifiesHeightWhileMeasuring = false

    private(set) var measurementCount = 0
    private(set) var maximumMeasurementDepth = 0
    private var measurementDepth = 0

    let headerConfiguration: TKBottomSheetHeaderConfiguration?
    var didUpdateHeight: (() -> Void)?
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

    init(
        contentHeight: CGFloat,
        title: TKBottomSheetHeaderConfiguration.Title
    ) {
        self.contentHeight = contentHeight
        headerConfiguration = TKBottomSheetHeaderConfiguration(
            title: title,
            rightButton: .close()
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        measurementCount += 1
        measurementDepth += 1
        maximumMeasurementDepth = max(maximumMeasurementDepth, measurementDepth)
        defer { measurementDepth -= 1 }

        if notifiesHeightWhileMeasuring {
            didUpdateHeight?()
        }

        return contentHeight
    }
}
