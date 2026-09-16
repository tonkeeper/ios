@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class TKBottomSheetHeaderViewTests: XCTestCase {
    private var window: UIWindow!
    private var container: UIView!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let viewController = UIViewController()
        window.rootViewController = viewController
        window.isHidden = false
        viewController.view.frame = window.bounds
        container = UIView(frame: window.bounds)
        viewController.view.addSubview(container)
        viewController.view.layoutIfNeeded()
    }

    override func tearDown() {
        window = nil
        container = nil
        super.tearDown()
    }

    /// `TKBottomSheetViewController` measures the header before it has ever assigned it a frame, so a
    /// measurement that leaked the current frame width made the sheet open with a header hundreds of
    /// points too tall and snap once the content reported its height.
    func testHeightIsStableAcrossMeasurementsOfAFreshHeader() {
        let headerView = makeHeaderView(
            title: .title(title: "Network fee", subtitle: "Choose method")
        )

        let firstPass = measure(headerView, width: 390)
        headerView.frame = CGRect(x: 0, y: 0, width: 390, height: firstPass)
        container.layoutIfNeeded()
        let secondPass = measure(headerView, width: 390)

        XCTAssertEqual(firstPass, secondPass, accuracy: 0.5)
    }

    func testHeightIsStableForAMultilineSubtitle() {
        let headerView = makeHeaderView(
            title: .title(
                title: "Network fee",
                subtitle: "Choose the method you want to use to pay the network fee for this transaction"
            )
        )

        let firstPass = measure(headerView, width: 390)
        headerView.frame = CGRect(x: 0, y: 0, width: 390, height: firstPass)
        container.layoutIfNeeded()
        let secondPass = measure(headerView, width: 390)

        XCTAssertEqual(firstPass, secondPass, accuracy: 0.5)
    }

    func testHeightIgnoresTheCurrentFrameHeight() {
        let headerView = makeHeaderView(
            title: .title(title: "Network fee", subtitle: "Choose method")
        )

        headerView.frame = CGRect(x: 0, y: 0, width: 390, height: 500)
        container.layoutIfNeeded()
        let measuredWhileTall = measure(headerView, width: 390)

        headerView.frame = CGRect(x: 0, y: 0, width: 390, height: 1)
        container.layoutIfNeeded()
        let measuredWhileShort = measure(headerView, width: 390)

        XCTAssertEqual(measuredWhileTall, measuredWhileShort, accuracy: 0.5)
    }

    /// A sizing query must stay free of layout side effects — Auto Layout calls it during a layout
    /// pass, where mutating layout is how measurement turns into a layout loop.
    func testMeasuringDoesNotResizeTheHeader() {
        let headerView = makeHeaderView(
            title: .title(title: "Network fee", subtitle: "Choose method")
        )
        headerView.frame = CGRect(x: 0, y: 0, width: 120, height: 44)
        container.layoutIfNeeded()

        _ = measure(headerView, width: 390)

        XCTAssertEqual(headerView.frame, CGRect(x: 0, y: 0, width: 120, height: 44))
    }

    func testRenderContentIsIdempotentForTheSameWidth() {
        let headerView = makeHeaderView(
            title: .title(title: "Network fee", subtitle: "Choose method")
        )

        headerView.renderContent(forWidth: 390)
        let firstHeight = measure(headerView, width: 390)

        headerView.renderContent(forWidth: 390)
        headerView.renderContent(forWidth: 390.4)

        XCTAssertEqual(headerView.bounds.width, 390, accuracy: 0.01)
        XCTAssertEqual(measure(headerView, width: 390), firstHeight, accuracy: 0.5)
    }

    func testRenderContentIgnoresDegenerateWidths() {
        let headerView = makeHeaderView(
            title: .title(title: "Network fee", subtitle: "Choose method")
        )
        headerView.renderContent(forWidth: 390)

        headerView.renderContent(forWidth: 0)
        headerView.renderContent(forWidth: -10)
        headerView.renderContent(forWidth: .nan)
        headerView.renderContent(forWidth: .infinity)

        XCTAssertEqual(headerView.bounds.width, 390, accuracy: 0.01)
    }

    func testHeightFollowsTheRequestedWidth() {
        let headerView = makeHeaderView(
            title: .title(
                title: "Network fee",
                subtitle: "Choose the method you want to use to pay the network fee for this transaction"
            )
        )

        XCTAssertGreaterThan(
            measure(headerView, width: 200),
            measure(headerView, width: 390)
        )
    }

    /// The accessory buttons set the height of a title-less header, so their metrics are part of the
    /// sheet's layout contract: 32pt of button between the configured 16pt insets.
    func testCloseOnlyHeaderIsAsTallAsItsButtonPlusInsets() {
        let headerView = makeHeaderView(title: .empty)

        XCTAssertEqual(measure(headerView, width: 390), 64, accuracy: 0.5)
    }

    func testTitleIconButtonKeepsTheAccessoryButtonHeight() {
        let headerView = TKBottomSheetHeaderView()
        container.addSubview(headerView)
        headerView.configure(
            configuration: TKBottomSheetHeaderConfiguration(
                title: .empty,
                leftButton: .init(
                    content: .titleIcon(
                        title: "Edit",
                        icon: .TKUIKit.Icons.Size16.chevronDown
                    ),
                    action: { _ in }
                )
            )
        )

        XCTAssertEqual(measure(headerView, width: 390), 64, accuracy: 0.5)
    }

    /// A multiline subtitle wraps against the width left over after `ModalCardHeader` reserves room
    /// for the accessory buttons, and that reservation comes from geometry read while rendering — so
    /// rendering at the target width first is what makes the first measurement final.
    func testRenderingBeforeMeasuringAccountsForAccessoryButtons() {
        let title = TKBottomSheetHeaderConfiguration.Title.title(
            title: "Network fee",
            subtitle: "Choose the method you want to use for paying the network fee of this transfer now"
        )

        let freshHeaderView = makeHeaderView(title: title)
        freshHeaderView.renderContent(forWidth: 390)
        let firstPass = measure(freshHeaderView, width: 390)

        let settledHeaderView = makeHeaderView(title: title)
        settledHeaderView.frame = CGRect(x: 0, y: 0, width: 390, height: 100)
        container.layoutIfNeeded()
        _ = measure(settledHeaderView, width: 390)
        let settled = measure(settledHeaderView, width: 390)

        let singleLineHeaderView = makeHeaderView(
            title: .title(title: "Network fee", subtitle: "Choose method")
        )
        singleLineHeaderView.renderContent(forWidth: 390)
        let singleLine = measure(singleLineHeaderView, width: 390)

        XCTAssertEqual(firstPass, settled, accuracy: 0.5)
        XCTAssertGreaterThan(settled, singleLine, "the subtitle should need more than one line at this width")
    }
}

private extension TKBottomSheetHeaderViewTests {
    func makeHeaderView(title: TKBottomSheetHeaderConfiguration.Title) -> TKBottomSheetHeaderView {
        let headerView = TKBottomSheetHeaderView()
        container.addSubview(headerView)
        headerView.configure(
            configuration: TKBottomSheetHeaderConfiguration(
                title: title,
                rightButton: .close()
            )
        )
        return headerView
    }

    func measure(_ headerView: TKBottomSheetHeaderView, width: CGFloat) -> CGFloat {
        headerView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }
}
