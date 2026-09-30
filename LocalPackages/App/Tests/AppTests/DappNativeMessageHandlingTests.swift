@testable import App
import KeeperCore
import XCTest

final class DappNativeMessageHandlingTests: XCTestCase {
    func test_navigateBackClosesTheScreen() throws {
        let handler = DefaultDappMessageHandler()
        var didNavigateBack = false
        handler.navigateBack = { didNavigateBack = true }

        let result = try invoke(handler, type: .uiNavigateBack, args: [])

        XCTAssertTrue(didNavigateBack)
        guard case .success = result else {
            return XCTFail("expected ui.navigateBack to resolve, got \(result)")
        }
    }

    func test_trackForwardsEventWithScalarParams() throws {
        let handler = DefaultDappMessageHandler()
        var tracked: (event: String, params: [String: Any])?
        handler.track = { tracked = ($0, $1) }

        let result = try invoke(
            handler,
            type: .analyticsTrack,
            args: [["event": "vault_open", "params": ["vault": "usdt", "apy": 4.2, "nested": ["a": 1]]]]
        )

        guard case .success = result else {
            return XCTFail("expected analytics.track to resolve, got \(result)")
        }
        XCTAssertEqual(tracked?.event, "vault_open")
        XCTAssertEqual(try Set(XCTUnwrap(tracked?.params).keys), ["vault", "apy"])
    }

    func test_trackWithoutEventIsRejectedAsInvalidParams() throws {
        let handler = DefaultDappMessageHandler()
        var tracked = false
        handler.track = { _, _ in tracked = true }

        let result = try invoke(handler, type: .analyticsTrack, args: [["params": ["vault": "usdt"]]])

        guard case let .rejected(code, message) = result else {
            return XCTFail("expected analytics.track without an event to reject, got \(result)")
        }
        XCTAssertEqual(code, DappNativeBridge.ErrorCode.invalidParams.rawValue)
        XCTAssertEqual(message, DappNativeBridge.ErrorMessage.missingEvent)
        XCTAssertFalse(tracked)
    }

    func test_trackWithBlankEventIsRejectedAsInvalidParams() throws {
        let handler = DefaultDappMessageHandler()

        let result = try invoke(handler, type: .analyticsTrack, args: [["event": "  "]])

        guard case let .rejected(code, _) = result else {
            return XCTFail("expected a blank event to reject, got \(result)")
        }
        XCTAssertEqual(code, DappNativeBridge.ErrorCode.invalidParams.rawValue)
    }

    func test_onlyNativeBridgeMethodsAreHostGated() {
        XCTAssertTrue(DappBridgeFunctionType.uiNavigateBack.isNativeBridge)
        XCTAssertTrue(DappBridgeFunctionType.analyticsTrack.isNativeBridge)
        XCTAssertFalse(DappBridgeFunctionType.send.isNativeBridge)
        XCTAssertFalse(DappBridgeFunctionType.tonapiFetch.isNativeBridge)
    }

    func test_rejectionIsDeliveredAsAnErrorObject() throws {
        let response = DappBridgeResponse(
            invocationId: "1",
            status: .rejected,
            data: .nativeError(
                code: DappNativeBridge.ErrorCode.unsupportedMethod.rawValue,
                message: DappNativeBridge.ErrorMessage.unsupportedMethod
            )
        )

        let json = try XCTUnwrap(response.json)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(json.data(using: .utf8))) as? [String: Any]
        )
        let error = try XCTUnwrap(decoded["data"] as? [String: Any])

        XCTAssertEqual(decoded["status"] as? String, "rejected")
        XCTAssertEqual(error["code"] as? Int, 1)
        XCTAssertEqual(error["message"] as? String, "Unsupported method")
    }
}

private extension DappNativeMessageHandlingTests {
    func invoke(
        _ handler: DefaultDappMessageHandler,
        type: DappBridgeFunctionType,
        args: [Any]
    ) throws -> DappMessageHandlerResult {
        var result: DappMessageHandlerResult?
        try handler.handleFunctionInvokeMessage(
            DappFunctionInvokeMessage(type: type, invocationId: "1", args: args),
            dapp: makeDapp()
        ) { result = $0 }
        return try XCTUnwrap(result)
    }

    func makeDapp() throws -> Dapp {
        try Dapp(
            name: "Earn",
            description: nil,
            icon: nil,
            poster: nil,
            url: XCTUnwrap(URL(string: "https://vaults.fyi")),
            textColor: nil,
            excludeCountries: nil,
            includeCountries: nil
        )
    }
}
