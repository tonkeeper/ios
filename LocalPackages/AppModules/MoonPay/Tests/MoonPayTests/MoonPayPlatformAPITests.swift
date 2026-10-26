@testable import MoonPay
import XCTest

final class MoonPayPlatformAPITests: XCTestCase {
    private var api: MoonPayPlatformAPI!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        api = MoonPayPlatformAPI(environment: .sandbox, urlSession: URLSession(configuration: configuration))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testCreateSessionSendsSecretKeyAndDecodesToken() async throws {
        let recorded = StubURLProtocol.respond(status: 200, body: #"{"sessionToken":"sess_1"}"#)

        let token = try await api.createSession(secretKey: "sk_test_123", request: MoonPayCreateSessionRequest(deviceIp: "1.2.3.4"))

        XCTAssertEqual(token, MoonPaySessionToken(rawValue: "sess_1"))
        let request = try XCTUnwrap(recorded.request)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.moonpay.dev/platform/v1/sessions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "sk_test_123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(recorded.bodyString, #"{"deviceIp":"1.2.3.4"}"#)
    }

    func testBuyQuoteSendsBearerTokenAndDecodesDocumentedResponse() async throws {
        let recorded = StubURLProtocol.respond(status: 200, body: #"""
        {"data":{
            "source":{"amount":"100.00","asset":{"code":"USD"}},
            "destination":{"amount":"0.00114","asset":{"code":"BTC"}},
            "fees":{
                "network":{"amount":"2.39","asset":{"code":"USD"}},
                "moonpay":{"amount":"4.99","asset":{"code":"USD"}},
                "ecosystem":{"amount":"1.00","asset":{"code":"USD"}}
            },
            "wallet":{"address":"0x1234"},
            "paymentMethod":{"type":"apple_pay"},
            "feeBehavior":"inclusive",
            "expiresAt":"2026-03-27T12:30:00.000Z",
            "executable":true,
            "exchangeRate":87523.17,
            "exchangeRateType":"fixed",
            "signature":"cXVvdGUuc2lnbmF0dXJl",
            "paymentDisclosures":[{"id":"eea-crypto-asset-risk","version":"1"}]
        }}
        """#)
        let quoteRequest = MoonPayBuyQuoteRequest(
            source: MoonPayMoney(amount: "100", asset: MoonPayAsset(code: "USD")),
            destination: MoonPayMoney(asset: MoonPayAsset(code: "BTC")),
            wallet: MoonPayWalletReference(address: "0x1234"),
            paymentMethod: MoonPayPaymentMethodReference(type: "apple_pay")
        )

        let quote = try await api.buyQuote(accessToken: "acc_1", request: quoteRequest)

        let request = try XCTUnwrap(recorded.request)
        XCTAssertEqual(request.url?.absoluteString, "https://api.moonpay.dev/platform/v1/quotes/buy")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer acc_1")
        XCTAssertEqual(
            recorded.bodyString,
            #"{"destination":{"asset":{"code":"BTC"}},"paymentMethod":{"type":"apple_pay"},"source":{"amount":"100","asset":{"code":"USD"}},"wallet":{"address":"0x1234"}}"#
        )

        XCTAssertEqual(quote.signature, "cXVvdGUuc2lnbmF0dXJl")
        XCTAssertTrue(quote.executable)
        XCTAssertEqual(quote.destination.amount, "0.00114")
        XCTAssertEqual(quote.destination.asset.code, "BTC")
        XCTAssertEqual(quote.fees?["network"]?.amount, "2.39")
        XCTAssertEqual(quote.fees?.count, 3)
        XCTAssertEqual(quote.exchangeRate, "87523.17")
        XCTAssertEqual(quote.exchangeRateType, "fixed")
        XCTAssertEqual(quote.feeBehavior, .inclusive)
        XCTAssertEqual(quote.expiresAt, MoonPayJSONCoding.parseISO8601("2026-03-27T12:30:00.000Z"))
        XCTAssertEqual(quote.paymentDisclosures?.first?.id, "eea-crypto-asset-risk")
        XCTAssertNil(quote.challengeURL)
    }

    func testQuoteChallengeURL() async throws {
        _ = StubURLProtocol.respond(status: 200, body: #"{"data":{"source":{"asset":{"code":"USD"}},"destination":{"asset":{"code":"TON"}},"executable":false,"signature":"s","challenge":{"url":"https://platform.moonpay.com/platform/v1/challenge?challengeToken=t"}}}"#)
        let quote = try await api.buyQuote(accessToken: "acc", request: MoonPayBuyQuoteRequest(
            source: MoonPayMoney(amount: "30", asset: MoonPayAsset(code: "USD")),
            destination: MoonPayMoney(asset: MoonPayAsset(code: "TON"))
        ))
        XCTAssertFalse(quote.executable)
        XCTAssertEqual(quote.challengeURL?.query, "challengeToken=t")
    }

    func testAssetsSendsBearerGETAndDecodesPage() async throws {
        let recorded = StubURLProtocol.respond(status: 200, body: #"""
        {"data":[
            {"caip19":"eip155:1/slip44:60","code":"ETH","name":"Ethereum","network":"ethereum","source":"cefi","contractAddress":null,"decimals":18,"precision":6,"status":{"suspended":false,"disabled":false}},
            {"caip19":"tron:0x2b6653dc/trc20:TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t","code":"USDT_TRX","name":"Tether (Tron)","network":"tron","source":"cefi","contractAddress":"TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t","decimals":6,"precision":2,"status":{"suspended":true,"disabled":false}}
        ],"pageInfo":{"nextCursor":"next_1"}}
        """#)

        let page = try await api.assets(accessToken: "acc_1", source: .cefi, cursor: "c0", limit: 2)

        let request = try XCTUnwrap(recorded.request)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/platform/v1/assets")
        let items = try URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first { $0.name == "source" }?.value, "cefi")
        XCTAssertEqual(items?.first { $0.name == "cursor" }?.value, "c0")
        XCTAssertEqual(items?.first { $0.name == "limit" }?.value, "2")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer acc_1")
        XCTAssertEqual(page.nextCursor, "next_1")
        XCTAssertEqual(page.assets.map(\.code), ["ETH", "USDT_TRX"])
        XCTAssertNil(page.assets[0].contractAddress)
        XCTAssertTrue(page.assets[0].isAvailable)
        XCTAssertFalse(page.assets[1].isAvailable)
        XCTAssertEqual(page.assets[1].quoteReference, MoonPayAsset(code: "USDT_TRX"))
    }

    func testTransactionSendsBearerGETAndDecodesStages() async throws {
        let recorded = StubURLProtocol.respond(status: 200, body: #"""
        {"data":{
            "id":"txn_1","status":"failed","transactionHash":null,
            "customer":{"id":"cus_9"},
            "stages":[
                {"kind":"ordering","name":"Ordering","status":"success","failureReason":null},
                {"kind":"waiting_authentication","name":"Authentication","status":"failed","failureReason":"three_ds_failure"}
            ]
        }}
        """#)

        let transaction = try await api.transaction(accessToken: "acc_1", id: "txn_1")

        let request = try XCTUnwrap(recorded.request)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://api.moonpay.dev/platform/v1/transactions/txn_1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer acc_1")
        XCTAssertEqual(transaction.id, "txn_1")
        XCTAssertTrue(transaction.isFailed)
        XCTAssertFalse(transaction.isCompleted)
        XCTAssertEqual(transaction.customerID, "cus_9")
        XCTAssertEqual(transaction.failedStage?.failureReason, "three_ds_failure")
    }

    func testPaymentMethodsSendsBearerGETAndDecodesDocumentedResponse() async throws {
        let recorded = StubURLProtocol.respond(status: 200, body: #"""
        {"data":{
            "paymentMethodConfigs":[
                {"type":"apple_pay","capabilities":{"supportedCurrencies":["USD","EUR"],"supportedTransactionTypes":["buy"],"allowsDeletion":false,"requiresWidget":false},"availability":{"active":true,"reasons":[]}},
                {"type":"card","capabilities":{"supportedCurrencies":["USD"],"supportedTransactionTypes":["buy","sell"],"allowsDeletion":true,"requiresWidget":false},"availability":{"active":true,"reasons":[]}},
                {"type":"sepa","capabilities":{"supportedCurrencies":["EUR"],"supportedTransactionTypes":["buy"],"allowsDeletion":false,"requiresWidget":true},"availability":{"active":false,"reasons":["unsupported_region"]}}
            ],
            "paymentMethods":[
                {"id":"a1b2","type":"card","cardType":"credit","brand":"visa","last4":"4242","expirationMonth":"03","expirationYear":"2028","availability":{"active":true,"reasons":[]}},
                {"id":"c3d4","type":"card","cardType":"debit","brand":"mastercard","last4":"8910","expirationMonth":"01","expirationYear":"2024","availability":{"active":false,"reasons":["card_expired"]}},
                {"id":"apple_pay_fakeid","type":"apple_pay"}
            ]
        }}
        """#)

        let methods = try await api.paymentMethods(accessToken: "acc_1", currency: "USD")

        let request = try XCTUnwrap(recorded.request)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://api.moonpay.dev/platform/v1/payment-methods?currency=USD")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer acc_1")
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertNil(recorded.body)

        XCTAssertEqual(methods.configs.map(\.type), ["apple_pay", "card", "sepa"])
        XCTAssertEqual(methods.activeConfigs.map(\.type), ["apple_pay", "card"])
        XCTAssertEqual(methods.configs[0].capabilities?.supportedCurrencies, ["USD", "EUR"])
        XCTAssertEqual(methods.configs[1].capabilities?.allowsDeletion, true)
        XCTAssertTrue(methods.configs[1].supportsBuy)
        XCTAssertEqual(methods.configs[2].capabilities?.requiresWidget, true)
        XCTAssertEqual(methods.configs[2].availability?.reasons, ["unsupported_region"])
        XCTAssertEqual(methods.stored.map(\.last4), ["4242", "8910"])
        XCTAssertEqual(methods.activeStored.map(\.id), ["a1b2"])
        XCTAssertEqual(methods.stored[0].expirationMonth, "03")
        XCTAssertEqual(methods.stored[1].availability, MoonPayPaymentMethodAvailability(active: false, reasons: ["card_expired"]))
    }

    func testPaymentMethodsWithoutCurrencyOmitsQueryAndToleratesSparseResponse() async throws {
        let recorded = StubURLProtocol.respond(status: 200, body: #"{"data":{"paymentMethodConfigs":[{"type":"pix"}]}}"#)

        let methods = try await api.paymentMethods(accessToken: "acc_1")

        XCTAssertEqual(recorded.request?.url?.absoluteString, "https://api.moonpay.dev/platform/v1/payment-methods")
        XCTAssertNil(recorded.request?.url?.query)
        XCTAssertEqual(methods.configs.map(\.type), ["pix"])
        XCTAssertNil(methods.configs[0].capabilities)
        XCTAssertNil(methods.configs[0].availability)
        XCTAssertFalse(methods.configs[0].isActive)
        XCTAssertTrue(methods.configs[0].supportsBuy)
        XCTAssertEqual(methods.stored, [])
    }

    func testHTTPErrorCarriesServerBody() async {
        _ = StubURLProtocol.respond(status: 400, body: #"{"code":"validationError","message":"Invalid request","errors":[{"field":"deviceIp","message":"required"}]}"#)
        do {
            _ = try await api.createSession(secretKey: "sk_test_1", request: MoonPayCreateSessionRequest(deviceIp: ""))
            XCTFail("expected an error")
        } catch let MoonPayAPIError.http(status, body) {
            XCTAssertEqual(status, 400)
            XCTAssertEqual(body?.code, "validationError")
            XCTAssertEqual(body?.errors?.first?.field, "deviceIp")
            XCTAssertEqual(
                MoonPayAPIError.http(status: status, body: body).errorDescription,
                "MoonPay API HTTP 400 (validationError — Invalid request — deviceIp: required)"
            )
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testQuoteAmountLimitIsReadFromErrorDetails() async {
        _ = StubURLProtocol.respond(status: 400, body: #"{"code":"invalid_request","message":"Invalid request","errors":[{"field":"source.amount","message":"Source amount is too low. Minimum is 20 USD","details":{"minBuyAmount":"20"}}]}"#)
        await assertQuoteLimit(.belowMinimum(20))

        _ = StubURLProtocol.respond(status: 400, body: #"{"code":"invalid_request","message":"Invalid request","errors":[{"field":"source.amount","message":"Source amount is too high. Maximum is 29850 USD","details":{"maxBuyAmount":"29850"}}]}"#)
        await assertQuoteLimit(.aboveMaximum(29850))
    }

    func testQuoteErrorWithoutLimitDetailsHasNoAmountLimit() async {
        _ = StubURLProtocol.respond(status: 400, body: #"{"code":"invalid_request","message":"Invalid request","errors":[{"field":"wallet.address","message":"required"}]}"#)
        await assertQuoteLimit(nil)
    }

    private func assertQuoteLimit(_ expected: MoonPayBuyAmountLimit?, file: StaticString = #filePath, line: UInt = #line) async {
        let request = MoonPayBuyQuoteRequest(
            source: MoonPayMoney(amount: "1", asset: MoonPayAsset(code: "usd")),
            destination: MoonPayMoney(asset: MoonPayAsset(code: "eth")),
            wallet: MoonPayWalletReference(address: "0x1")
        )
        do {
            _ = try await api.buyQuote(accessToken: "acc_1", request: request)
            XCTFail("expected an error", file: file, line: line)
        } catch let error as MoonPayAPIError {
            XCTAssertEqual(error.buyAmountLimit, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }

    func testRateLimit() async {
        _ = StubURLProtocol.respond(status: 429, body: "")
        do {
            _ = try await api.buyQuote(accessToken: "a", request: MoonPayBuyQuoteRequest(
                source: MoonPayMoney(amount: "1", asset: MoonPayAsset(code: "USD")),
                destination: MoonPayMoney(asset: MoonPayAsset(code: "TON"))
            ))
            XCTFail("expected an error")
        } catch MoonPayAPIError.rateLimited {
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testDecodingFailureIsReported() async {
        _ = StubURLProtocol.respond(status: 200, body: #"{"unexpected":true}"#)
        do {
            _ = try await api.createSession(secretKey: "sk_test_1", request: MoonPayCreateSessionRequest(deviceIp: "1.1.1.1"))
            XCTFail("expected an error")
        } catch MoonPayAPIError.decoding {
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testCreateSessionRequestEncodesOptionalFieldsAndDates() throws {
        let request = MoonPayCreateSessionRequest(
            deviceIp: "1.1.1.1",
            externalCustomerId: "cust",
            email: "a@b.c",
            termsAcceptedAt: Date(timeIntervalSince1970: 1_774_614_600)
        )
        let json = try String(decoding: MoonPayJSONCoding.makeEncoder().encode(request), as: UTF8.self)
        XCTAssertEqual(json, #"{"deviceIp":"1.1.1.1","email":"a@b.c","externalCustomerId":"cust","termsAcceptedAt":"2026-03-27T12:30:00.000Z"}"#)
    }
}

// MARK: - Stub transport

final class RecordedRequest {
    var request: URLRequest?
    var body: Data?

    var bodyString: String? {
        body.map { String(decoding: $0, as: UTF8.self) }
    }
}

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest, Data?) -> (Int, Data))?

    static func respond(status: Int, body: String) -> RecordedRequest {
        let recorded = RecordedRequest()
        handler = { request, bodyData in
            recorded.request = request
            recorded.body = bodyData
            return (status, Data(body.utf8))
        }
        return recorded
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let (status, body) = handler(request, Self.bodyData(of: request))
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands the body to a protocol as a stream, not as `httpBody`.
    private static func bodyData(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
