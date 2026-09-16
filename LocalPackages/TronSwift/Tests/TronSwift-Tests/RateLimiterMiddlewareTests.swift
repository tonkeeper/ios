import Foundation
import Testing
@testable import TronSwiftAPI

struct RateLimiterMiddlewareTests {
    @Test
    func methodKeyCollapsesAddressSegments() {
        #expect(
            RateLimiterMiddleware.methodKey(for: "/v1/accounts/TBfH7xxrEtwD48QjHUvV7vuvXDy21hNQkQ")
                == "v1/accounts/*"
        )
        #expect(
            RateLimiterMiddleware.methodKey(for: "/v1/accounts/TBfH7xxrEtwD48QjHUvV7vuvXDy21hNQkQ/transactions/trc20")
                == "v1/accounts/*/transactions/trc20"
        )
    }

    @Test
    func methodKeyKeepsMethodSegments() {
        #expect(RateLimiterMiddleware.methodKey(for: "/wallet/getaccount") == "wallet/getaccount")
        #expect(RateLimiterMiddleware.methodKey(for: "/jsonrpc") == "jsonrpc")
    }
}
