@testable import AppUI
import OperationReviewModels
import SwiftUI
@testable import TKUIKit
import UIKit
import XCTest

/// The findings sheet's answer, against stand-ins for presenting and dismissing it: UIKit does not
/// finish presentations in the test bundle.
@MainActor
final class OperationConsentPresenterTests: XCTestCase {
    func test_theAnswerComesOnceTheSheetIsGoneAndOnlyOnce() async throws {
        for isConfirmed in [true, false] {
            let (host, window) = hostInWindow()
            defer { window.isHidden = true }
            let sheets = Sheets()
            let presenter = sheets.presenter(host: host)

            let asking = sheets.ask(presenter)
            let sheet = try await presentedSheet(in: sheets)
            let findings = try sheet.findings()
            let (tap, otherTap) = isConfirmed ? (findings.onConfirm, findings.onCancel) : (findings.onCancel, findings.onConfirm)
            XCTAssertTrue(sheets.sources.first === host)
            tap()
            // UIKit reports the sheet's navigation controller dismissed just before the dismissal completes.
            sheets.takeAway(sheet)
            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(sheets.dismissed.count, 1)
            XCTAssertEqual(sheets.answers, [], "answered before the sheet was gone")

            sheets.finishDismissal()
            let answer = try await settledAnswer(of: asking, from: presenter, in: sheets)
            sheets.finishDismissal()
            otherTap()
            sheet.didClose?(true)

            XCTAssertEqual(answer, isConfirmed)
            XCTAssertEqual(sheets.answers, [isConfirmed])
            XCTAssertEqual(sheets.dismissed.count, 1)
        }
    }

    func test_swipingTheSheetAwayIsCancel() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)

        let asking = sheets.ask(presenter)
        try await presentedSheet(in: sheets).didClose?(true)
        let answer = try await settledAnswer(of: asking, from: presenter, in: sheets)

        XCTAssertFalse(answer)
        XCTAssertEqual(sheets.dismissed.count, 0)
    }

    /// A deeplink closes every modal, the sheet with them, while a pushed host stays on screen.
    func test_aSheetTakenAwayUnansweredIsCancelAndTheNextReviewIsAsked() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)

        let asking = sheets.ask(presenter)
        try await sheets.takeAway(presentedSheet(in: sheets))
        let answer = try await settledAnswer(of: asking, from: presenter, in: sheets)
        let next = sheets.ask(presenter)
        try await waitUntil { sheets.presented.count == 2 }
        sheets.presented.last?.didClose?(true)
        _ = try await settledAnswer(of: next, from: presenter, in: sheets, count: 2)

        XCTAssertFalse(answer)
        XCTAssertEqual(sheets.presented.count, 2)
    }

    /// The tap's dismissal loses its completion with the sheet's navigation controller.
    func test_aSheetTakenAwayAsItSlidesOutAnswersTheTap() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)

        let asking = sheets.ask(presenter)
        let sheet = try await presentedSheet(in: sheets)
        try sheet.findings().onConfirm()
        sheet.dismiss()
        sheets.takeAway(sheet)
        let answer = try await settledAnswer(of: asking, from: presenter, in: sheets)
        sheets.finishDismissal()

        XCTAssertTrue(answer)
        XCTAssertEqual(sheets.answers, [true])
    }

    func test_aSheetUIKitDidNotPresentIsCancel() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets(presentsNothing: true)
        let presenter = sheets.presenter(host: host)

        let answer = try await settledAnswer(of: sheets.ask(presenter), from: presenter, in: sheets)
        _ = try await settledAnswer(of: sheets.ask(presenter), from: presenter, in: sheets, count: 2)

        XCTAssertFalse(answer)
        XCTAssertEqual(sheets.presented.count, 2, "the next review was not asked")
    }

    func test_nothingIsAskedWithoutAHostInAWindow() async throws {
        for host in [nil, UIViewController()] {
            let sheets = Sheets()
            let presenter = sheets.presenter(host: host)

            let answer = try await settledAnswer(of: sheets.ask(presenter), from: presenter, in: sheets)

            XCTAssertFalse(answer)
            XCTAssertEqual(sheets.presented.count, 0)
        }
    }

    func test_theSheetIsPresentedFromTheModalOverTheHost() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let modal = UIViewController()
        host.present(modal, animated: false)
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)

        let asking = sheets.ask(presenter)
        try await presentedSheet(in: sheets).didClose?(true)
        _ = try await settledAnswer(of: asking, from: presenter, in: sheets)

        XCTAssertTrue(sheets.sources.first === modal)
    }

    func test_nothingIsAskedOverASheetThatIsClosing() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let closing = TKBottomSheetViewController(contentViewController: TKBottomSheetHostingController(content: EmptyView()))
        host.present(UINavigationController(rootViewController: closing), animated: false)
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)
        closing.dismiss()
        XCTAssertTrue(closing.isDismissing)

        let answer = try await settledAnswer(of: sheets.ask(presenter), from: presenter, in: sheets)

        XCTAssertFalse(answer)
        XCTAssertEqual(sheets.presented.count, 0)
    }

    func test_nothingElseIsAskedWhileAReviewIsPending() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)

        let asking = sheets.ask(presenter)
        let sheet = try await presentedSheet(in: sheets)
        let second = try await settledAnswer(of: sheets.ask(presenter), from: presenter, in: sheets)
        sheet.didClose?(true)
        _ = try await settledAnswer(of: asking, from: presenter, in: sheets, count: 2)

        XCTAssertFalse(second)
        XCTAssertEqual(sheets.presented.count, 1)
    }

    func test_aHostThatLeftRefusesThePendingReviewAndEveryLaterOne() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)

        let asking = sheets.ask(presenter)
        let sheet = try await presentedSheet(in: sheets)
        presenter.hostDidLeave()
        let answer = try await settledAnswer(of: asking, from: presenter, in: sheets)
        let later = sheets.ask(presenter)
        try await waitUntil { sheets.answers.count == 2 }
        later.cancel()
        let laterAnswer = await later.value

        XCTAssertFalse(answer)
        XCTAssertTrue(sheets.dismissed.first === sheet)
        XCTAssertFalse(laterAnswer)
        XCTAssertEqual(sheets.presented.count, 1)
    }

    func test_aHostDismissingItsModalStackRefusesWithoutStartingAnotherDismissal() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)
        let asking = sheets.ask(presenter)
        _ = try await presentedSheet(in: sheets)

        presenter.hostDidLeave(dismissSheet: false)
        let answer = try await settledAnswer(of: asking, from: presenter, in: sheets)

        XCTAssertFalse(answer)
        XCTAssertTrue(sheets.dismissed.isEmpty)
        let later = await presenter.ask(.flagged)
        XCTAssertFalse(later)
    }

    func test_aCancelledTaskIsRefusedAndItsSheetClosed() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)

        let cancelledBeforeAsking = sheets.ask(presenter)
        cancelledBeforeAsking.cancel()
        let refused = try await settledAnswer(of: cancelledBeforeAsking, from: presenter, in: sheets)
        let asking = sheets.ask(presenter)
        let sheet = try await presentedSheet(in: sheets)
        asking.cancel()
        let answer = try await settledAnswer(of: asking, from: presenter, in: sheets, count: 2)

        XCTAssertFalse(refused)
        XCTAssertFalse(answer)
        XCTAssertEqual(sheets.presented.count, 1)
        XCTAssertTrue(sheets.dismissed.first === sheet)
    }

    func test_aConsentAsksThroughThePresenterOncePerReview() async throws {
        let (host, window) = hostInWindow()
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)
        let consent = presenter.consent()

        let first = sheets.ask(consent)
        try await presentedSheet(in: sheets).findings().onConfirm()
        sheets.finishDismissal()
        let accepted = try await settledAnswer(of: first, from: presenter, in: sheets)
        let again = try await settledAnswer(of: sheets.ask(consent), from: presenter, in: sheets, count: 2)

        XCTAssertTrue(accepted)
        XCTAssertTrue(again)
        XCTAssertEqual(sheets.presented.count, 1)
    }

    /// On an iPhone SE a few findings with addresses are taller than the sheet can grow.
    func test_aLongListOfFindingsScrollsToItsButtons() async throws {
        let (host, window) = hostInWindow(size: CGSize(width: 375, height: 667))
        defer { window.isHidden = true }
        let sheets = Sheets()
        let presenter = sheets.presenter(host: host)

        let asking = sheets.ask(presenter, .longList)
        let sheet = try await presentedSheet(in: sheets)
        host.addChild(sheet)
        sheet.view.frame = host.view.bounds
        host.view.addSubview(sheet.view)
        sheet.didMove(toParent: host)
        sheet.view.layoutIfNeeded()
        sheet.startPresentation()
        sheet.view.layoutIfNeeded()
        let scrollView = try XCTUnwrap(sheet.contentViewController as? TKBottomSheetScrollHostingController<OperationFindingsView>).scrollView
        scrollView.layoutIfNeeded()

        XCTAssertLessThanOrEqual(sheet.containerView.frame.height, host.view.bounds.height)
        XCTAssertTrue(scrollView.isScrollEnabled)
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)

        sheet.didClose?(true)
        _ = try await settledAnswer(of: asking, from: presenter, in: sheets)
    }
}

private extension OperationConsentPresenterTests {
    func hostInWindow(size: CGSize = CGSize(width: 390, height: 844)) -> (UIViewController, UIWindow) {
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        return (host, window)
    }

    func presentedSheet(in sheets: Sheets) async throws -> TKBottomSheetViewController {
        try await waitUntil { !sheets.presented.isEmpty }
        return try XCTUnwrap(sheets.presented.first)
    }

    /// An ask still pending after the wait is refused through `hostDidLeave` and fails the test, which
    /// awaits only an ask that answered: one whose continuation leaked would hang it.
    func settledAnswer(
        of asking: Task<Bool, Never>,
        from presenter: OperationConsentPresenter,
        in sheets: Sheets,
        count: Int = 1
    ) async throws -> Bool {
        try await waitUntil { sheets.answers.count >= count }
        guard sheets.answers.count >= count else {
            presenter.hostDidLeave()
            throw Unanswered()
        }
        return await asking.value
    }

    func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(condition(), "timed out")
    }
}

private struct Unanswered: Error {}

private extension TKBottomSheetViewController {
    func findings() throws -> OperationFindingsView {
        try XCTUnwrap(contentViewController as? TKBottomSheetScrollHostingController<OperationFindingsView>).content
    }
}

private extension OperationReview {
    static let flagged = OperationReview(id: "flagged", findings: [
        OperationFinding(id: "flagged:0", kind: "Stub", severity: .warning, title: "Finding"),
    ])

    static let longList = OperationReview(id: "long", findings: (0 ..< 4).map {
        OperationFinding(
            id: "long:\($0)",
            kind: "Stub",
            severity: .danger,
            title: "Spends more than shown",
            details: "1,250 USDT instead of 125 USDT",
            subject: "0xdAC17F958D2ee523a2206206994597C13D831ec7"
        )
    })
}

@MainActor
private final class Sheets {
    private(set) var presented = [TKBottomSheetViewController]()
    private(set) var sources = [UIViewController]()
    private(set) var dismissed = [TKBottomSheetViewController]()
    private(set) var answers = [Bool]()
    private var dismissalCompletions = [() -> Void]()
    private var departures = [() -> Void]()
    private let presentsNothing: Bool

    /// `presentsNothing`: UIKit drops every presentation.
    init(presentsNothing: Bool = false) {
        self.presentsNothing = presentsNothing
    }

    func presenter(host: UIViewController?) -> OperationConsentPresenter {
        OperationConsentPresenter(
            host: { host },
            present: { [unowned self] sheet, source, sheetIsGone in
                presented.append(sheet)
                sources.append(source)
                departures.append(sheetIsGone)
                if presentsNothing {
                    sheetIsGone()
                }
            },
            dismiss: { [unowned self] sheet, completion in
                dismissed.append(sheet)
                dismissalCompletions.append(completion)
            }
        )
    }

    func ask(_ presenter: OperationConsentPresenter, _ review: OperationReview = .flagged) -> Task<Bool, Never> {
        record { await presenter.ask(review) }
    }

    func ask(_ consent: OperationConsent) -> Task<Bool, Never> {
        record { await consent(.flagged) }
    }

    /// The end of the first dismissal's animation.
    func finishDismissal() {
        dismissalCompletions.first?()
    }

    /// The sheet's navigation controller was dismissed, by the sheet or by anything else.
    func takeAway(_ sheet: TKBottomSheetViewController) {
        if let index = presented.firstIndex(where: { $0 === sheet }) {
            departures[index]()
        }
    }

    private func record(_ ask: @escaping @MainActor () async -> Bool) -> Task<Bool, Never> {
        Task {
            let answer = await ask()
            answers.append(answer)
            return answer
        }
    }
}
