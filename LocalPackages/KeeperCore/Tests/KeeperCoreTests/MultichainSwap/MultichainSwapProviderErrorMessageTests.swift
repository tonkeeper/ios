@testable import KeeperCore
import SwapAPI
import XCTest

final class MultichainSwapProviderErrorMessageTests: XCTestCase {
    func test_errorCode_parsesEverySchemaCode() {
        let schemaCodes: [SwapAPI.Components.Schemas.CrossSwapProviderErrorCode] = [
            .no_route, .asset_not_supported, .min_amount_not_met,
            .country_blocked, .provider_unavailable, .provider_error,
        ]

        for schemaCode in schemaCodes {
            XCTAssertEqual(
                makeError(code: schemaCode.rawValue).errorCode?.rawValue,
                schemaCode.rawValue
            )
        }
        XCTAssertEqual(
            Set(MultichainSwapProviderErrorCode.allCases.map(\.rawValue)),
            Set(schemaCodes.map(\.rawValue))
        )
    }

    func test_isNoRoute_onlyForTheNoRouteCode() {
        for code in MultichainSwapProviderErrorCode.allCases {
            XCTAssertEqual(makeError(code: code.rawValue).isNoRoute, code == .noRoute)
        }
        XCTAssertFalse(makeError(code: "brand_new_backend_code").isNoRoute)
    }

    func test_userMessage_isNilWithoutErrors() {
        XCTAssertNil(MultichainSwapProviderErrorMessage.userMessage(for: []))
    }

    func test_userMessage_neverLeaksTheProvidersOwnWording() {
        let rawMessage = "swapkit 503 tokenPriceUnavailable: Token TON.TON price unavailable"
        let message = MultichainSwapProviderErrorMessage.userMessage(
            for: [makeError(code: "provider_unavailable", message: rawMessage)]
        )

        XCTAssertNotNil(message)
        XCTAssertNotEqual(message, rawMessage)
    }

    func test_userMessage_tellsTheCodesApart() {
        let messages = MultichainSwapProviderErrorCode.allCases.map(userMessage(for:))

        XCTAssertEqual(Set(messages).count, MultichainSwapProviderErrorCode.allCases.count)
    }

    func test_userMessage_fallsBackToTheGenericTextForAnUnknownCode() {
        XCTAssertEqual(
            MultichainSwapProviderErrorMessage.userMessage(for: [makeError(code: "brand_new_backend_code")]),
            userMessage(for: .providerError)
        )
    }

    /// The shape of a swap under swaps.xyz's minimum: swaps.xyz reports it as an unclassified
    /// provider error, and only SwapKit's code says what the user can do about it.
    func test_userMessage_prefersTheMinimumAmountOverAnUnclassifiedProviderError() {
        let message = MultichainSwapProviderErrorMessage.userMessage(for: [
            makeError(aggregator: "swapsxyz", code: "provider_error"),
            makeError(aggregator: "swapkit", code: "min_amount_not_met"),
        ])

        XCTAssertEqual(message, userMessage(for: .minAmountNotMet))
    }

    func test_userMessage_prefersABlockedRegionOverEveryOtherCode() {
        for code in MultichainSwapProviderErrorCode.allCases where code != .countryBlocked {
            let message = MultichainSwapProviderErrorMessage.userMessage(for: [
                makeError(aggregator: "swapkit", code: code.rawValue),
                makeError(aggregator: "swapsxyz", code: "country_blocked"),
            ])

            XCTAssertEqual(message, userMessage(for: .countryBlocked), "\(code)")
        }
    }

    /// One aggregator not knowing the asset does not make the asset unavailable — the pair is what
    /// the user cannot swap.
    func test_userMessage_prefersTheMissingRouteOverAnUnsupportedAsset() {
        let message = MultichainSwapProviderErrorMessage.userMessage(for: [
            makeError(aggregator: "swapkit", code: "asset_not_supported"),
            makeError(aggregator: "swapsxyz", code: "no_route"),
        ])

        XCTAssertEqual(message, userMessage(for: .noRoute))
    }

    func test_userMessage_prefersAnyClassifiedCodeOverAnOutage() {
        let message = MultichainSwapProviderErrorMessage.userMessage(for: [
            makeError(aggregator: "swapkit", code: "provider_unavailable"),
            makeError(aggregator: "swapsxyz", code: "asset_not_supported"),
        ])

        XCTAssertEqual(message, userMessage(for: .assetNotSupported))
    }

    func test_userMessage_ignoresTheOrderErrorsArriveIn() {
        let errors = [
            makeError(aggregator: "swapkit", protocolSlug: "flashnet", code: "provider_unavailable"),
            makeError(aggregator: "swapkit", protocolSlug: "chainflip", code: "min_amount_not_met"),
            makeError(aggregator: "swapsxyz", code: "provider_error"),
        ]

        XCTAssertEqual(
            MultichainSwapProviderErrorMessage.userMessage(for: errors),
            MultichainSwapProviderErrorMessage.userMessage(for: errors.reversed())
        )
    }

    func test_logDescription_keepsProviderCodeAndRawMessage() {
        let description = MultichainSwapProviderErrorMessage.logDescription(for: [
            makeError(
                aggregator: "swapkit",
                protocolSlug: "flashnet",
                code: "min_amount_not_met",
                message: "sellAssetAmountTooSmall: Sell asset amount too small for provider FLASHNET."
            ),
            makeError(aggregator: "swapsxyz", code: "provider_error", message: "The specified amount is too low."),
        ])

        XCTAssertEqual(
            description,
            "swapkit/flashnet:min_amount_not_met(sellAssetAmountTooSmall: Sell asset amount too small for provider FLASHNET.),"
                + "swapsxyz:provider_error(The specified amount is too low.)"
        )
    }

    func test_logDescription_isEmptyWithoutErrors() {
        XCTAssertEqual(MultichainSwapProviderErrorMessage.logDescription(for: []), "")
    }
}

private extension MultichainSwapProviderErrorMessageTests {
    func makeError(
        aggregator: String = "swapkit",
        protocolSlug: String? = nil,
        code: String,
        message: String = "raw provider message"
    ) -> MultichainSwapProviderError {
        MultichainSwapProviderError(
            aggregator: aggregator,
            protocolSlug: protocolSlug,
            code: code,
            message: message
        )
    }

    func userMessage(for code: MultichainSwapProviderErrorCode) -> String? {
        MultichainSwapProviderErrorMessage.userMessage(for: [makeError(code: code.rawValue)])
    }
}
