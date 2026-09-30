import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import TKLogging
import XCTest

final class APILoggingTests: XCTestCase {
    // MARK: - ClientError rendering

    func testClientErrorDescriptionCarriesTheWholeChain() {
        let error = makeClientError(
            underlying: URLError(.notConnectedToInternet),
            causeDescription: "Transport threw an error.",
            response: HTTPResponse(status: .init(code: 503))
        )

        XCTAssertEqual(
            error.logDescription,
            """
            type=OpenAPIRuntime.ClientError, operationID=createCrossSwapQuote, method=POST, \
            path=/v2/cross/quote, status=503, cause=Transport threw an error., \
            underlying=[type=Foundation.URLError, code=-1009, reason=notConnectedToInternet]
            """
        )
    }

    func testClientErrorDescriptionKeepsHeadersInputAndBodiesOut() throws {
        var request = HTTPRequest(method: .post, scheme: nil, authority: nil, path: "/v2/cross/quote")
        request.headerFields[.authorization] = "Bearer secret-token"
        let error = try ClientError(
            operationID: "createCrossSwapQuote",
            operationInput: "secret-input",
            request: request,
            requestBody: HTTPBody(#"{"address":"secret-address"}"#),
            baseURL: XCTUnwrap(URL(string: "https://swap.tonkeeper.com")),
            response: HTTPResponse(status: .badRequest),
            responseBody: HTTPBody(#"{"error":"secret-response"}"#),
            causeDescription: "Unknown",
            underlyingError: URLError(.badServerResponse)
        )

        let description = error.logDescription
        for secret in ["secret-token", "secret-input", "secret-address", "secret-response"] {
            XCTAssertFalse(description.contains(secret), "leaked \(secret)")
        }
    }

    func testClientErrorDescriptionReducesQueryToItsKeys() {
        let error = makeClientError(
            path: "/v2/onramp/config?fiat=EUR&q=my-search-term&device_country_code=DE"
        )

        XCTAssertTrue(
            error.logDescription.contains("path=/v2/onramp/config?fiat,q,device_country_code"),
            error.logDescription
        )
        XCTAssertFalse(error.logDescription.contains("my-search-term"))
    }

    func testClientErrorDescriptionUnwrapsNestedDecodingFailure() {
        struct Payload: Decodable {
            let amount: String
        }
        let data = Data(#"{"amount":42}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(Payload.self, from: data)) { decodingError in
            let error = makeClientError(underlying: decodingError, causeDescription: "Unknown")

            XCTAssertTrue(
                error.logDescription.contains(
                    "underlying=[type=Swift.DecodingError, case=typeMismatch, expected=String, path=amount]"
                ),
                error.logDescription
            )
        }
    }

    // MARK: - Middleware

    func testMiddlewareLogsErrorStatusWithServerPayloadAndForwardsBodyIntact() async throws {
        let backend = RecordingLogBackend()
        let payload = #"{"error":"pair not allowed","code":"pair_not_allowed"}"#
        let (_, body) = try await withRecording(backend) {
            try await send(response: response(status: 400, json: payload))
        }

        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.severity, .warning)
        XCTAssertEqual(record.category, "API")
        XCTAssertTrue(record.message.hasPrefix("createCrossSwapQuote POST /v2/cross/quote → 400 in"), record.message)
        XCTAssertEqual(record.extraInfo["responseBody"], payload)
        XCTAssertEqual(record.extraInfo["host"], "swap.tonkeeper.com")

        let forwarded = try await Data(collecting: XCTUnwrap(body), upTo: 1024)
        XCTAssertEqual(String(decoding: forwarded, as: UTF8.self), payload)
    }

    func testMiddlewareLeavesStreamedErrorBodyUntouched() async throws {
        let backend = RecordingLogBackend()
        var fields = HTTPFields()
        fields[.contentType] = "application/json"
        let (_, body) = try await withRecording(backend) {
            try await send(
                response: (
                    HTTPResponse(status: .init(code: 500), headerFields: fields),
                    HTTPBody(#"{"error":"boom"}"#)
                )
            )
        }

        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.severity, .warning)
        XCTAssertEqual(record.extraInfo["responseBody"], "<not captured>")

        let forwarded = try await Data(collecting: XCTUnwrap(body), upTo: 1024)
        XCTAssertEqual(String(decoding: forwarded, as: UTF8.self), #"{"error":"boom"}"#)
    }

    /// Buffering the payload is the optional half; losing the status because it failed would
    /// leave the worst case — a broken error response — as the one with no log at all.
    func testMiddlewareStillReportsStatusWhenErrorBodyCannotBeRead() async throws {
        let backend = RecordingLogBackend()
        var fields = HTTPFields()
        fields[.contentType] = "application/json"
        fields[.contentLength] = "32"
        let unreadable = AsyncThrowingStream<ArraySlice<UInt8>, any Error> {
            $0.finish(throwing: URLError(.networkConnectionLost))
        }

        do {
            _ = try await withRecording(backend) {
                try await send(
                    response: (
                        HTTPResponse(status: .init(code: 500), headerFields: fields),
                        HTTPBody(unreadable, length: .unknown)
                    )
                )
            }
            XCTFail("expected the unreadable body to reach the caller")
        } catch {}

        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.severity, .warning)
        XCTAssertTrue(record.message.contains("→ 500 in"), record.message)
        XCTAssertEqual(record.extraInfo["responseBody"], "<unreadable>")
    }

    /// A prompt, usable response is the overwhelming majority of calls, so it is recorded at debug
    /// — present for a developer reading a live console, and below the severity a release build
    /// keeps, so it never shortens the window an exported log covers.
    func testMiddlewareRecordsAPromptSuccessAtDebug() async throws {
        let backend = RecordingLogBackend()
        _ = try await withRecording(backend) {
            try await send(response: response(status: 200, json: #"{"ok":true}"#))
        }

        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.severity, .debug)
        XCTAssertTrue(record.message.contains("→ 200 in"), record.message)
        XCTAssertNil(record.extraInfo["responseBody"])
    }

    func testAPromptSuccessIsBelowTheSeverityAReleaseBuildKeeps() async throws {
        let backend = RecordingLogBackend()
        _ = try await withRecording(backend, minimumSeverity: .info) {
            try await send(response: response(status: 200, json: #"{"ok":true}"#))
        }

        XCTAssertTrue(backend.records.isEmpty, backend.records.map(\.message).pretty.string)
    }

    func testMiddlewareReportsASuccessThatTookTooLong() async throws {
        let backend = RecordingLogBackend()
        _ = try await withRecording(backend) {
            try await send(
                response: response(status: 200, json: #"{"ok":true}"#),
                slowRequestThreshold: 0
            )
        }

        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.severity, .info)
        XCTAssertTrue(record.message.hasSuffix("- slow"), record.message)
        XCTAssertTrue(record.message.contains("→ 200 in"), record.message)
    }

    func testMiddlewareReportsTransportFailureAsWarningAndRethrows() async throws {
        let backend = RecordingLogBackend()

        do {
            _ = try await withRecording(backend) {
                try await send(failure: makeClientError(underlying: URLError(.timedOut)))
            }
            XCTFail("expected the transport failure to reach the caller")
        } catch {}

        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.severity, .warning)
        XCTAssertTrue(record.message.contains("→ failed in"), record.message)
        XCTAssertEqual(
            record.extraInfo["error"],
            """
            type=OpenAPIRuntime.ClientError, operationID=createCrossSwapQuote, method=POST, \
            path=/v2/cross/quote, cause=Transport threw an error., \
            underlying=[type=Foundation.URLError, code=-1001, reason=timedOut]
            """
        )
    }

    /// A cancelled request is the user typing the next character, not a failure worth a warning.
    func testMiddlewareKeepsCancellationOutOfWarnings() async throws {
        let backend = RecordingLogBackend()

        do {
            _ = try await withRecording(backend) {
                try await send(failure: makeClientError(underlying: CancellationError()))
            }
            XCTFail("expected the cancellation to reach the caller")
        } catch {}

        XCTAssertEqual(backend.records.last?.severity, .info)
    }
}

private extension APILoggingTests {
    func makeClientError(
        path: String = "/v2/cross/quote",
        underlying: any Error = URLError(.unknown),
        causeDescription: String = "Transport threw an error.",
        response: HTTPResponse? = nil
    ) -> ClientError {
        ClientError(
            operationID: "createCrossSwapQuote",
            operationInput: "input",
            request: HTTPRequest(method: .post, scheme: nil, authority: nil, path: path),
            baseURL: URL(string: "https://swap.tonkeeper.com")!,
            response: response,
            causeDescription: causeDescription,
            underlyingError: underlying
        )
    }

    func response(status: Int, json: String) -> (HTTPResponse, HTTPBody?) {
        let data = Data(json.utf8)
        var fields = HTTPFields()
        fields[.contentType] = "application/json"
        fields[.contentLength] = "\(data.count)"
        return (HTTPResponse(status: .init(code: status), headerFields: fields), HTTPBody(data))
    }

    func withRecording<T>(
        _ backend: RecordingLogBackend,
        minimumSeverity: LogSeverity = .debug,
        _ work: () async throws -> T
    ) async rethrows -> T {
        let configuration = Log.configuration
        defer { Log.configuration = configuration }
        Log.configuration = LoggingConfiguration(
            minimumSeverity: minimumSeverity,
            defaultSubsystem: "test",
            backends: [backend]
        )
        return try await work()
    }

    /// Runs the middleware the way `UniversalClient` does.
    func send(
        response: (HTTPResponse, HTTPBody?)? = nil,
        failure: (any Error)? = nil,
        slowRequestThreshold: TimeInterval = 3
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try await APILoggingMiddleware(slowRequestThreshold: slowRequestThreshold).intercept(
            HTTPRequest(method: .post, scheme: nil, authority: nil, path: "/v2/cross/quote"),
            body: nil,
            baseURL: URL(string: "https://swap.tonkeeper.com")!,
            operationID: "createCrossSwapQuote",
            next: { _, _, _ in
                if let failure {
                    throw failure
                }
                return response ?? (HTTPResponse(status: .ok), nil)
            }
        )
    }
}

private final class RecordingLogBackend: LogBackend, @unchecked Sendable {
    private(set) var records = [LogRecord]()

    func log(_ record: LogRecord) {
        records.append(record)
    }
}
