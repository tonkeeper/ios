@testable import App
import XCTest

@MainActor
final class UserAnswerTests: XCTestCase {
    func testTheReplyIsTheAnswer() async {
        let yes = await answer { $0(true) }
        let no = await answer { $0(false) }

        XCTAssertEqual(yes, true)
        XCTAssertEqual(no, false)
    }

    func testOnlyTheFirstReplyCounts() async {
        let first = await answer { reply in
            reply(true)
            reply(false)
        }

        XCTAssertEqual(first, true)
    }

    func testNobodyToAskIsANo() async {
        let unasked = await answer { _ in }

        XCTAssertEqual(unasked, false)
    }

    /// An alert torn down without a tap releases the reply its actions hold.
    func testAReplyReleasedUnansweredIsANo() async {
        let alert = HeldReply()
        let asked = expectation(description: "asked")
        let answered = expectation(description: "answered")
        let result = Answer()
        Task {
            result.value = await UserAnswer.ask { reply in
                alert.reply = reply
                asked.fulfill()
            }
            answered.fulfill()
        }
        await fulfillment(of: [asked], timeout: 1)
        XCTAssertNil(result.value, "the question waits while the alert is up")

        alert.reply = nil

        await fulfillment(of: [answered], timeout: 1)
        XCTAssertEqual(result.value, false)
    }

    private func answer(_ question: @escaping (_ reply: @escaping (Bool) -> Void) -> Void) async -> Bool? {
        let answered = expectation(description: "answered")
        let result = Answer()
        Task {
            result.value = await UserAnswer.ask(question)
            answered.fulfill()
        }
        await fulfillment(of: [answered], timeout: 1)
        return result.value
    }
}

@MainActor
private final class Answer {
    var value: Bool?
}

@MainActor
private final class HeldReply {
    var reply: ((Bool) -> Void)?
}
