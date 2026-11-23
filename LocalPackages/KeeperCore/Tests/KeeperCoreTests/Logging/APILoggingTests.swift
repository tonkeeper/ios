import ChainKit
import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import PerpsModels
import TKFeatureFlags
import TKLogging
import TonAPI
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

    func testFundingHTTPLogsCorrelationAtInfoWithoutSignedBodies() async throws {
        let backend = RecordingLogBackend()
        var request = HTTPRequest(method: .post, scheme: nil, authority: nil, path: "/funding/quote")
        request.headerFields[.contentType] = "application/json"
        let body = #"{"operation":{"signature":"secret-signature"}}"#
        let returned = try await withRecording(backend, minimumSeverity: .info) {
            try await PerpsOperationLog.$context.withValue(["trace_id": "funding-trace", "flow": "deposit"]) {
                try await APILoggingMiddleware(bodyLoggedOperations: ["quoteDeposit"]).intercept(
                    request, body: HTTPBody(body), baseURL: URL(string: "https://perps.test")!, operationID: "quoteDeposit"
                ) { _, _, _ in
                    self.response(status: 200, json: body)
                }
            }
        }
        let forwarded = try await Data(collecting: XCTUnwrap(returned.1), upTo: 4096)
        XCTAssertEqual(forwarded, Data(body.utf8))
        let record = try XCTUnwrap(backend.records.first)
        XCTAssertEqual(record.extraInfo["trace_id"], "funding-trace")
        XCTAssertTrue(record.message.contains("quoteDeposit POST /funding/quote → 200"))
        XCTAssertNil(record.extraInfo["requestBody"])
        XCTAssertNil(record.extraInfo["responseBody"])
        let errorEnvelope = #"{"code":"upstream_unavailable","details":{"reason":"lighter_unavailable"}}"#
        _ = try await withRecording(backend, minimumSeverity: .info) {
            try await PerpsOperationLog.$context.withValue(["trace_id": "funding-trace", "flow": "deposit"]) {
                try await send(response: response(status: 503, json: errorEnvelope))
            }
        }
        let refusal = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(refusal.extraInfo["trace_id"], "funding-trace")
        XCTAssertEqual(refusal.extraInfo["responseBody"], errorEnvelope)
        XCTAssertNil(refusal.extraInfo["requestBody"])
    }

    func testFundingStatusPollDoesNotLogEverySuccessfulHTTPRead() async throws {
        let backend = RecordingLogBackend()
        _ = try await withRecording(backend, minimumSeverity: .info) {
            try await PerpsOperationLog.$context.withValue(["trace_id": "poll-trace", "poll": "true"]) {
                try await send()
            }
        }
        XCTAssertTrue(backend.records.isEmpty)
    }

    func testFundingFailureBeforeQuoteKeepsContextAndSource() async throws {
        let backend = RecordingLogBackend()
        await withRecording(backend) {
            do {
                try await PerpsOperationLog.step("review_input", fields: ["flow": "deposit", "asset_id": "sol/mainnet/coin", "amount": "0.0383"]) {
                    throw PerpsDepositQuoteError.malformedKeyRegistration("trading key unavailable")
                }
            } catch {}
        }
        let started = try XCTUnwrap(backend.records.first)
        let failed = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(failed.extraInfo["trace_id"], started.extraInfo["trace_id"])
        XCTAssertNotNil(failed.extraInfo["trace_id"])
        XCTAssertEqual(failed.extraInfo["asset_id"], "sol/mainnet/coin")
        XCTAssertEqual(failed.extraInfo["amount"], "0.0383")
        XCTAssertEqual(failed.extraInfo["source"], "wallet")
        XCTAssertEqual(failed.extraInfo["outcome"], "failed")
        XCTAssertTrue(failed.extraInfo["error"]?.contains("trading key unavailable") == true)
    }

    func testFundingCancellationIsLoggedAndContextDoesNotLeak() async throws {
        let backend = RecordingLogBackend()
        await withRecording(backend) {
            do {
                try await PerpsOperationLog.step("quote", fields: ["flow": "withdraw"]) {
                    throw CancellationError()
                }
            } catch {}
            XCTAssertTrue(PerpsOperationLog.context.isEmpty)
        }
        let cancelled = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(cancelled.severity, .info)
        XCTAssertEqual(cancelled.extraInfo["outcome"], "cancelled")
    }

    func testFundingNestedStepsRetainTraceAndRestoreParentFields() async {
        let backend = RecordingLogBackend()
        await withRecording(backend) {
            await PerpsOperationLog.step("review", fields: ["flow": "deposit", "asset_id": "sol/mainnet/coin"]) {
                let trace = PerpsOperationLog.context["trace_id"]
                await PerpsOperationLog.step("quote", fields: ["quote_id": "q-1"]) {
                    XCTAssertEqual(PerpsOperationLog.context["trace_id"], trace)
                    XCTAssertEqual(PerpsOperationLog.context["asset_id"], "sol/mainnet/coin")
                }
                XCTAssertNil(PerpsOperationLog.context["quote_id"])
            }
        }
        XCTAssertEqual(Set(backend.records.compactMap { $0.extraInfo["trace_id"] }).count, 1)
    }

    func testConcurrentFundingAttemptsHaveIndependentTraces() async {
        let backend = RecordingLogBackend()
        await withRecording(backend) {
            await withTaskGroup(of: Void.self) { group in
                for wallet in ["wallet-a", "wallet-b"] {
                    group.addTask {
                        await PerpsOperationLog.step("review", fields: ["flow": "deposit", "wallet_id": wallet]) {
                            await Task.yield()
                            PerpsOperationLog.event("quote", outcome: "started", source: "backend")
                        }
                    }
                }
            }
        }
        let records = backend.records
        let first = Set(records.filter { $0.extraInfo["wallet_id"] == "wallet-a" }.compactMap { $0.extraInfo["trace_id"] })
        let second = Set(records.filter { $0.extraInfo["wallet_id"] == "wallet-b" }.compactMap { $0.extraInfo["trace_id"] })
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
        XCTAssertTrue(first.isDisjoint(with: second))
    }

    func testFundingSourceDistinguishesBackendLighterAndAmbiguousTransport() {
        XCTAssertEqual(PerpsAPIError.badStatus(.init(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "lighter_rejected")).operationLogSource, "lighter")
        XCTAssertEqual(PerpsAPIError.badStatus(.undecoded(500, message: "internal")).operationLogSource, "backend")
        XCTAssertEqual(PerpsAPIError.transport(underlying: URLError(.timedOut)).operationLogSource, "network")
        XCTAssertEqual(PerpsAPIError.transport(underlying: nil).operationLogSource, "unknown")
        let refusal = PerpsAPIError.badStatus(.init(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "amount_too_low", minUsdAmount: "2.95"))
        XCTAssertEqual(refusal.operationLogFields["http_status"], "400")
        XCTAssertEqual(refusal.operationLogFields["reason"], "amount_too_low")
        XCTAssertEqual(refusal.operationLogFields["min_usd_amount"], "2.95")
    }

    func testTradingExecutionCallbackRestoresTraceBeforeMappingOriginalFailure() async throws {
        let failure = PerpsAPIError.badStatus(.init(httpStatus: 400, code: "validation_error", message: nil, retryable: false, reason: "lighter_rejected"))
        let api = AccountStubAPI(account: .init(), onNextNonce: { throw failure })
        let backend = RecordingLogBackend()
        await withRecording(backend) {
            let relay = await PerpsOperationLog.withContext(fields: ["flow": "trade", "trace_id": "trade-trace", "operation_id": "op", "market_id": "7"]) {
                PerpsExecutionRelay(lane: PerpsSubmitLane(api: api, apiKeyIndex: 3), persistState: { _, _ in })
            }
            XCTAssertTrue(PerpsOperationLog.context.isEmpty)
            let error: Error? = await withCheckedContinuation { continuation in
                relay.nextNonce(scope: PerpsScope(walletId: "wallet", venue: "lighter", chainId: 304, environment: "mainnet", accountIndex: 42, keyBindingId: "42/3", expectedPublicKey: "public")) { _, error in
                    continuation.resume(returning: error)
                }
            }
            XCTAssertNotNil(error)
        }
        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.extraInfo["trace_id"], "trade-trace")
        XCTAssertEqual(record.extraInfo["operation_id"], "op")
        XCTAssertEqual(record.extraInfo["market_id"], "7")
        XCTAssertEqual(record.extraInfo["delegate_stage"], "nextNonce")
        XCTAssertEqual(record.extraInfo["source"], "lighter")
        XCTAssertEqual(record.extraInfo["reason"], "lighter_rejected")
        XCTAssertEqual(record.extraInfo["domain_error"], "serverRejected")
    }

    func testTradingJournalPreservesTraceAcrossIOAndOmitsSignedPayload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directory)
        let pending = PerpsPendingTradingAction(
            operationId: "trade-op", walletId: "wallet", marketId: 7, side: .long, payload: .close,
            orderRefs: [.init(role: .close, clientOrderIndex: 17)],
            signedSteps: [.init(stepId: "close", attemptId: "attempt", nonce: 5, transactionExpiryUnixMs: 1000, txType: 14, txInfo: "secret-signed-payload", txHash: "public-hash", state: .sending)]
        )
        let backend = RecordingLogBackend()
        try await withRecording(backend) {
            try await PerpsOperationLog.withContext(fields: ["flow": "trade", "trace_id": "trade-op", "review_id": "review"]) {
                _ = try await journal.savePendingIfAbsentWithStatus(pending)
            }
        }
        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.extraInfo["trace_id"], "trade-op")
        XCTAssertEqual(record.extraInfo["review_id"], "review")
        XCTAssertEqual(record.extraInfo["outcome"], "saved")
        XCTAssertEqual(record.extraInfo["action"], "close")
        XCTAssertEqual(record.extraInfo["step_states"], "close:sending")
        XCTAssertEqual(record.extraInfo["tx_hashes"], "public-hash")
        XCTAssertEqual(record.extraInfo["order_indices"], "close:17")
        XCTAssertFalse(record.extraInfo.values.contains { $0.contains("secret-signed-payload") })
    }

    func testTradingUnknownCancellationAndNoopKeepDistinctOutcomes() async {
        let backend = RecordingLogBackend()
        await withRecording(backend) {
            await PerpsOperationLog.withContext(fields: ["flow": "trade", "operation_id": "op"]) {
                PerpsOperationLog.event("submit", outcome: "failed", error: PerpsTradingError.unknown("secret-payload"))
                PerpsOperationLog.event("submit", outcome: "failed", error: PerpsTradingError.activationCanceled)
                PerpsOperationLog.event("prepare", outcome: "noop", error: PerpsTradingError.nothingToChange)
            }
        }
        XCTAssertEqual(backend.records.map { $0.extraInfo["outcome"] }, ["unknown", "cancelled", "noop"])
        XCTAssertEqual(backend.records.map(\.severity), [.warning, .info, .info])
        XCTAssertEqual(backend.records.first?.extraInfo["source"], "unknown")
        XCTAssertFalse(backend.records.flatMap { $0.extraInfo.values }.contains { $0.contains("secret-payload") })
    }

    // MARK: - Middleware

    func testTonAPIClientLogsHTTPErrorBeforeThrowingWithBodyIntact() async throws {
        let backend = RecordingLogBackend()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TonAPIErrorURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = try TonAPI.Client(
            serverURL: XCTUnwrap(URL(string: "https://tonapi.test")),
            apiKey: "secret-token",
            urlSession: session
        )

        do {
            _ = try await withRecording(backend) {
                try await client.status()
            }
            XCTFail("expected TonAPIError")
        } catch {
            let apiError = try XCTUnwrap(error.tonAPIError)
            XCTAssertEqual(apiError.statusCode, 503)
            XCTAssertEqual(apiError.body, Data(TonAPIErrorURLProtocol.payload.utf8))
            XCTAssertEqual(apiError.path, "/v2/status")
        }

        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.severity, .warning)
        XCTAssertEqual(record.category, "TonAPI")
        XCTAssertTrue(record.message.contains("→ 503 cf-ray=test-ray in"), record.message)
        XCTAssertEqual(record.extraInfo["responseBody"], TonAPIErrorURLProtocol.payload)
        XCTAssertEqual(record.extraInfo["host"], "tonapi.test")
    }

    func testTonAPIBulkRequestLogsHTTPErrorWithBodyAndCanonicalPath() async throws {
        let backend = RecordingLogBackend()
        let session = makeTonAPISession()
        defer { session.invalidateAndCancel() }
        let api = try makeTonAPI(session: session)

        do {
            _ = try await withRecording(backend) {
                try await api.getWalletsByPubkeysBulk(publicKeys: ["public-key"], firebaseUserId: "firebase-user")
            }
            XCTFail("expected TonAPIError")
        } catch let error as TonAPIError {
            XCTAssertEqual(error.statusCode, 503)
            XCTAssertEqual(error.body, Data(TonAPIErrorURLProtocol.payload.utf8))
            XCTAssertEqual(error.path, "/v2/pubkeys/wallets/_bulk")
        }

        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.category, "TonAPI")
        XCTAssertEqual(record.severity, .warning)
        XCTAssertTrue(record.message.hasPrefix("getWalletsByPubkeysBulk POST /v2/pubkeys/wallets/_bulk → 503"), record.message)
        XCTAssertEqual(record.extraInfo["responseBody"], TonAPIErrorURLProtocol.payload)
    }

    func testTonAPIMigrationLogsConflictAndPreservesPreparedResponse() async throws {
        let backend = RecordingLogBackend()
        let session = makeTonAPISession()
        defer { session.invalidateAndCancel() }
        let api = try makeTonAPI(session: session)

        let response = try await withRecording(backend) {
            try await api.prepareMigration(from: "from", to: "to", currency: .USD, publicKey: "public-key")
        }

        XCTAssertTrue(response.isInsufficientTonConflict)
        XCTAssertEqual(response.details?.required, 250_000_000)
        let record = try XCTUnwrap(backend.records.last)
        XCTAssertEqual(record.category, "TonAPI")
        XCTAssertEqual(record.severity, .warning)
        XCTAssertTrue(record.message.hasPrefix("prepareMigration POST /v2/migration/prepare → 409"), record.message)
        XCTAssertEqual(record.extraInfo["responseBody"], TonAPIErrorURLProtocol.migrationPayload)
    }

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

    /// The decoder spends the body before a decoding failure surfaces, so the failure can say what
    /// the server sent only when the middleware handed it a buffered copy.
    func testUndecodedSuccessBodyIsReadableOnlyForABufferedOperation() async throws {
        let payload = #"{"operation":{"id":"1"}}"#
        func undecoded(bodies: Set<String>) async throws -> String? {
            var fields = HTTPFields()
            fields[.contentType] = "application/json"
            let streamed = HTTPBody(
                AsyncStream { $0.yield(ArraySlice(payload.utf8)); $0.finish() },
                length: .unknown,
                iterationBehavior: .single
            )
            let (response, body) = try await send(response: (HTTPResponse(status: .ok, headerFields: fields), streamed), bodies: bodies)
            _ = try await Data(collecting: XCTUnwrap(body), upTo: 1024)
            return await makeClientError(response: response, responseBody: body).undecodedResponseBody()
        }

        let buffered = try await undecoded(bodies: ["createCrossSwapQuote"])
        XCTAssertEqual(buffered, payload)
        let streamed = try await undecoded(bodies: [])
        XCTAssertNil(streamed)
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
    func makeTonAPISession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TonAPIErrorURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    func makeTonAPI(session: URLSession) throws -> API {
        let mainnet = try JSONDecoder().decode(BootConfiguration.self, from: Data(#"{"tonApiV2Key":"secret-token"}"#.utf8))
        return API(
            hostProvider: TonAPIHostProviderStub(),
            urlSession: session,
            configuration: Configuration(
                bootConfigurationService: TonAPIBootConfigurationStub(bootConfigurations: .init(mainnet: mainnet, testnet: .empty)),
                featureFlags: DummyFeatureFlags(),
                tkAppSettings: TonAPIAppSettingsStub()
            )
        )
    }

    func makeClientError(
        path: String = "/v2/cross/quote",
        underlying: any Error = URLError(.unknown),
        causeDescription: String = "Transport threw an error.",
        response: HTTPResponse? = nil,
        responseBody: HTTPBody? = nil
    ) -> ClientError {
        ClientError(
            operationID: "createCrossSwapQuote",
            operationInput: "input",
            request: HTTPRequest(method: .post, scheme: nil, authority: nil, path: path),
            baseURL: URL(string: "https://swap.tonkeeper.com")!,
            response: response,
            responseBody: responseBody,
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
        slowRequestThreshold: TimeInterval = 3,
        bodies: Set<String> = []
    ) async throws -> (HTTPResponse, HTTPBody?) {
        try await APILoggingMiddleware(slowRequestThreshold: slowRequestThreshold, bodyLoggedOperations: bodies).intercept(
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
    private let lock = NSLock()
    private var stored = [LogRecord]()

    var records: [LogRecord] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func log(_ record: LogRecord) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(record)
    }
}

private final class TonAPIErrorURLProtocol: URLProtocol {
    static let payload = #"{"error":"service unavailable"}"#
    static let migrationPayload = #"{"from":"from","to":"to","wallet_version":"v5R1","transactions":[],"error":"insufficient TON for gas","error_code":50000,"details":{"required":250000000,"available":10000000}}"#

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        let isMigration = request.url?.path == "/v2/migration/prepare"
        if request.url?.path == "/v2/pubkeys/wallets/_bulk" {
            XCTAssertEqual(request.value(forHTTPHeaderField: "F"), "firebase-user")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.httpMethod, "POST")
        }
        let data = Data((isMigration ? Self.migrationPayload : Self.payload).utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: isMigration ? 409 : 503,
            httpVersion: nil,
            headerFields: [
                "Content-Type": "application/json",
                "Content-Length": "\(data.count)",
                "cf-ray": "test-ray",
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct TonAPIHostProviderStub: APIHostProvider {
    var basePath: String {
        "https://tonapi.test"
    }
}

private struct TonAPIBootConfigurationStub: BootConfigurationService {
    let bootConfigurations: BootConfigurations

    func getConfiguration() throws -> BootConfigurations {
        bootConfigurations
    }

    func loadConfiguration() async throws -> BootConfigurations {
        bootConfigurations
    }
}

private final class TonAPIAppSettingsStub: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
}
