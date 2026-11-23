import OperationReviewModels
import XCTest

final class OperationConsentTests: XCTestCase {
    func test_aReviewWithNothingAboveInfoPassesWithoutAsking() async {
        let user = AskedUser(answer: false)
        let consent = OperationConsent { await user.ask($0) }

        let clean = await consent(review("clean"))
        let informed = await consent(review("info", .info, .info))

        XCTAssertTrue(clean)
        XCTAssertTrue(informed)
        let asked = await user.asked
        XCTAssertEqual(asked, [])
    }

    func test_anAcceptedReviewIsNotAskedAboutAgainInTheAttempt() async {
        let user = AskedUser(answer: true)
        let consent = OperationConsent { await user.ask($0) }

        let first = await consent(review("a", .info, .danger))
        let again = await consent(review("a", .danger))
        let milder = await consent(review("a", .warning))
        let other = await consent(review("b", .warning))

        XCTAssertEqual([first, again, milder, other], [true, true, true, true])
        let asked = await user.asked
        XCTAssertEqual(asked, ["a", "b"])
    }

    func test_theSameReviewAtAHigherSeverityIsAskedAboutAgain() async {
        let user = AskedUser(answer: true)
        let consent = OperationConsent { await user.ask($0) }

        _ = await consent(review("a", .warning))
        let escalated = await consent(review("a", .warning, .danger))
        let afterwards = await consent(review("a", .danger))

        XCTAssertEqual([escalated, afterwards], [true, true])
        let asked = await user.asked
        XCTAssertEqual(asked, ["a", "a"])
    }

    func test_aFreshAttemptAsksAgain() async {
        let user = AskedUser(answer: true)
        let attempt = OperationConsent { await user.ask($0) }
        let nextAttempt = OperationConsent { await user.ask($0) }

        _ = await attempt(review("a", .warning))
        let next = await nextAttempt(review("a", .warning))

        XCTAssertTrue(next)
        let asked = await user.asked
        XCTAssertEqual(asked, ["a", "a"])
    }

    func test_aRefusalIsNotRemembered() async {
        let user = AskedUser(answer: false)
        let consent = OperationConsent { await user.ask($0) }

        let first = await consent(review("a", .warning))
        let again = await consent(review("a", .warning))

        XCTAssertFalse(first)
        XCTAssertFalse(again)
        let asked = await user.asked
        XCTAssertEqual(asked, ["a", "a"])
    }

    func test_refuseRefusesWhatNeedsConsent() async {
        let warning = await OperationConsent.refuse(review("a", .warning))
        let danger = await OperationConsent.refuse(review("a", .danger))
        let info = await OperationConsent.refuse(review("a", .info))

        XCTAssertFalse(warning)
        XCTAssertFalse(danger)
        XCTAssertTrue(info)
    }

    private func review(_ id: String, _ severities: OperationFinding.Severity...) -> OperationReview {
        OperationReview(id: id, findings: severities.enumerated().map { index, severity in
            OperationFinding(id: "\(id):\(index)", kind: "Stub", severity: severity, title: "Finding \(index)")
        })
    }
}

private actor AskedUser {
    private let answer: Bool
    private(set) var asked = [String]()

    init(answer: Bool) {
        self.answer = answer
    }

    func ask(_ review: OperationReview) -> Bool {
        asked.append(review.id)
        return answer
    }
}
