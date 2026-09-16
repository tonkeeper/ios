import Foundation
import Testing
@testable import TronSwiftAPI

/// Android's `Tron429RetryInterceptor` reads the suspension out of the 429 body; iOS used to see only
/// the header, which TronGrid often omits.
struct TronRateLimitHintTests {
    @Test
    func suspensionIsReadFromTheBody() {
        #expect(cooldown(body: "the request rate of (getAccount) has been suspended for 1 s") == 1)
    }

    @Test
    func suspensionIsCaseInsensitive() {
        #expect(cooldown(body: "Suspended For 4 S") == 4)
    }

    @Test
    func suspensionWithoutSpaceBeforeUnitIsRead() {
        #expect(cooldown(body: "suspended for 12s") == 12)
    }

    @Test
    func fractionalSuspensionIsRead() {
        #expect(cooldown(body: "suspended for 1.5 s") == 1.5)
    }

    /// The header is the standard signal, so it wins when both are present.
    @Test
    func headerTakesPrecedenceOverTheBody() {
        #expect(cooldown(headers: ["Retry-After": "9"], body: "suspended for 1 s") == 9)
    }

    @Test
    func headerIsUsedWhenTheBodyCarriesNoHint() {
        #expect(cooldown(headers: ["Retry-After": "  7 "], body: "{\"Error\":\"rate exceeded\"}") == 7)
    }

    @Test
    func aBodyWithoutASuspensionYieldsNoHint() {
        #expect(cooldown(body: "request rate of (getAccount) exceeded the allowed_rps(1)") == nil)
    }

    @Test
    func emptyBodyYieldsNoHint() {
        #expect(cooldown(body: "") == nil)
    }

    /// A unit the parser does not know must not be read as seconds.
    @Test
    func aNonSecondUnitYieldsNoHint() {
        #expect(cooldown(body: "suspended for 5 minutes") == nil)
    }

    @Test
    func aMissingNumberYieldsNoHint() {
        #expect(cooldown(body: "suspended for a while") == nil)
    }

    private func cooldown(headers: [String: String]? = nil, body: String) -> TimeInterval? {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.trongrid.io/wallet/getaccount")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: headers
        )!
        return TronRateLimitHint.cooldown(response: response, data: Data(body.utf8))
    }
}
