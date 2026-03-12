@testable import KeeperCore
import XCTest

final class TonkeeperDeeplinkParserTests: XCTestCase {
    // Transfer deeplink

    func testTransferDeeplinkCommentDifferentEncodings() throws {
        let comment = "Дай денег"
        let notEncoded = "transfer/UQCRj3NEgSM_vvye0wJ1JSKKwuw9cfFHq63qq5G1sTSYDSpU?amount=100000000&text=Дай денег"
        let percentEncodedSpace = "transfer/UQCRj3NEgSM_vvye0wJ1JSKKwuw9cfFHq63qq5G1sTSYDSpU?amount=100000000&text=Дай%20денег"
        let percentEncodedComment = "transfer/UQCRj3NEgSM_vvye0wJ1JSKKwuw9cfFHq63qq5G1sTSYDSpU?amount=100000000&text=%D0%94%D0%B0%D0%B9%2520%D0%B4%D0%B5%D0%BD%D0%B5%D0%B3"

        try testTransferDeeplinkCommentParsing(deeplink: notEncoded, expectedComment: comment)
        try testTransferDeeplinkCommentParsing(deeplink: percentEncodedSpace, expectedComment: comment)
        try testTransferDeeplinkCommentParsing(deeplink: percentEncodedComment, expectedComment: comment)
    }

    private func testTransferDeeplinkCommentParsing(
        deeplink: String,
        expectedComment: String
    ) throws {
        let parser = TonkeeperDeeplinkParser()
        let parsed = try parser.parse(string: deeplink)

        guard case let .transfer(transfer) = parsed,
              case let .sendTransfer(sendTransfer) = transfer
        else {
            XCTFail()
            return
        }

        XCTAssertEqual(sendTransfer.comment, expectedComment)
    }
}
