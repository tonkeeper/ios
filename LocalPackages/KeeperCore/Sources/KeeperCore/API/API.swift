import BigInt
import Foundation
import HTTPTypes
@_spi(Generated) import OpenAPIRuntime
import StreamURLSessionTransport
import TKLogging
import TonAPI
import TonSwift

enum FetchError: Error {
    case wrongHost
    case unsupportedScheme
}

protocol APIHostProvider {
    var basePath: String { get async }
}

struct MainnetAPIHostProvider: APIHostProvider {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    var basePath: String {
        get async {
            await configuration.tonapiV2Endpoint
        }
    }
}

struct TestnetAPIHostProvider: APIHostProvider {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    var basePath: String {
        get async {
            await configuration.tonapiTestnetHost
        }
    }
}

struct API {
    private let hostProvider: APIHostProvider
    private let urlSession: URLSession
    private let configuration: Configuration

    init(
        hostProvider: APIHostProvider,
        urlSession: URLSession,
        configuration: Configuration
    ) {
        self.hostProvider = hostProvider
        self.urlSession = urlSession
        self.configuration = configuration
    }

    private func serverURL() async throws -> URL {
        let basePath = await hostProvider.basePath
        guard let url = URL(string: basePath) else {
            throw APIError.incorrectURL
        }
        return url
    }

    /// Only 429 is retried: the gateway rejects before processing, so a repeat is safe even for a
    /// broadcast. A 5xx or a transport failure leaves the outcome unknown and reaches the caller.
    private func perform<T>(
        headers: [String: String] = [:],
        attempt: Int = 0,
        _ call: (Client) async throws -> T
    ) async throws -> T {
        let client = try await Client(
            serverURL: serverURL(),
            apiKey: configuration.tonApiV2Key,
            urlSession: urlSession,
            headers: headers
        )
        do {
            return try await call(client)
        } catch {
            guard let apiError = error.tonAPIError else { throw error }
            guard apiError.statusCode == 429 else { throw apiError }
            return try await retryAfterRateLimit(apiError, attempt: attempt) {
                try await perform(headers: headers, attempt: attempt + 1, call)
            }
        }
    }

    /// A TonAPI POST using domain models rather than generated operation types.
    private func send<Body: Encodable, Response: Decodable>(
        _ operationID: String,
        path: String,
        body: Body,
        headers: [String: String] = [:],
        attempt: Int = 0
    ) async throws -> Response {
        let client = try await UniversalClient(
            serverURL: serverURL(),
            transport: URLSessionTransport(urlSession: urlSession),
            middlewares: .tonAPI(apiKey: configuration.tonApiV2Key, headers: headers)
        )
        do {
            let data = try await client.send(
                input: JSONEncoder().encode(body),
                forOperation: operationID,
                serializer: { data in
                    var request = HTTPRequest(method: .post, scheme: nil, authority: nil, path: path)
                    request.headerFields[.contentType] = "application/json"
                    return (request, HTTPBody(data))
                },
                deserializer: { _, body in
                    guard let body else { return Data() }
                    return try await Data(collecting: body, upTo: .max)
                }
            )
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            guard let apiError = error.tonAPIError else { throw error }
            guard apiError.statusCode == 429 else { throw apiError }
            return try await retryAfterRateLimit(apiError, attempt: attempt) {
                try await send(operationID, path: path, body: body, headers: headers, attempt: attempt + 1)
            }
        }
    }

    private func retryAfterRateLimit<T>(
        _ error: TonAPIError,
        attempt: Int,
        retry: () async throws -> T
    ) async throws -> T {
        guard attempt < TonAPIRateLimitBackoff.maxRetryCount else {
            Log.tonAPI.w("rate limited request out of retry attempts", extraInfo: [
                "path": error.path ?? "-",
                "attempts": "\(attempt + 1)",
            ])
            throw error
        }
        let delay = TonAPIRateLimitBackoff.delayNanoseconds(attempt: attempt)
        Log.tonAPI.w("rate limited request retrying after cooldown", extraInfo: [
            "path": error.path ?? "-",
            "attempt": "\(attempt + 1)",
            "delayMs": "\(delay / 1_000_000)",
        ])
        try await Task.sleep(nanoseconds: delay)
        try Task.checkCancellation()
        return try await retry()
    }
}

// MARK: - For Dapp bridge

extension API {
    func tonapiFetch(url: String, options: [String: Any]?) async throws -> (Data, URLResponse) {
        let uri = URL(string: url)
        if uri?.scheme != "https" {
            throw FetchError.unsupportedScheme
        }
        let host = uri?.host
        if host != "tonapi.io", host?.hasSuffix(".tonapi.io") == false {
            throw FetchError.wrongHost
        }

        var builder = URLRequest(url: uri!)

        let methodOptions = options?["method"] as? String ?? "GET"
        let headersOptions = options?["headers"] as? [String: String] ?? [:]
        let bodyOptions = options?["body"] as? String ?? ""
        var contentTypeOptions = "application/json"

        for (key, value) in headersOptions {
            if key == "Authorization" {
                builder.setValue(value, forHTTPHeaderField: "X-Authorization")
            } else if key == "Content-Type" {
                contentTypeOptions = value
            } else {
                builder.setValue(value, forHTTPHeaderField: key)
            }
        }

        let apiKey = await configuration.tonApiV2Key
        builder.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if methodOptions == "POST" {
            builder.httpBody = bodyOptions.data(using: .utf8)
            builder.setValue(contentTypeOptions, forHTTPHeaderField: "Content-Type")
            builder.httpMethod = "POST"
        }

        return try await urlSession.data(for: builder)
    }
}

// MARK: - Account

extension API {
    func getAccountInfo(accountId: String) async throws -> Account {
        let response = try await perform {
            try await $0.getAccount(path: .init(accountId: accountId)).ok.body.json
        }
        return try Account(account: response)
    }

    func getAccountJettonsBalances(address: Address, currencies: [Currency]) async throws -> [JettonBalance] {
        let response = try await perform {
            try await $0.getAccountJettonsBalances(
                path: .init(accountId: address.toRaw()),
                query: .init(currencies: currencies.map { $0.code }, supportedExtensions: ["custom_payload"])
            ).ok.body.json
        }
        return response.balances
            .compactMap { jetton in
                do {
                    let quantity = BigUInt(jetton.balance) ?? 0
                    let walletAddress = try Address.parse(jetton.walletAddress.address)
                    let rates = mapJettonRates(rates: jetton.price)
                    let jettonInfo = try JettonInfo(jettonPreview: jetton.jetton, extensions: jetton.extensions)
                    let jettonItem = JettonItem(jettonInfo: jettonInfo, walletAddress: walletAddress)
                    return JettonBalance(item: jettonItem, quantity: quantity, rates: rates)
                } catch {
                    return nil
                }
            }
    }

    private func mapJettonRates(rates: TonAPI.Components.Schemas.TokenRates?) -> [Currency: Rates.Rate] {
        var result = [Currency: Rates.Rate]()
        rates?.prices?.additionalProperties.forEach { currencyCode, value in
            guard let currency = Currency(code: currencyCode) else { return }
            let rate = Decimal(value)
            let diff24h = rates?.diff24h?.additionalProperties.first(where: { $0.key == currencyCode })?.value
            result[currency] = Rates.Rate(currency: currency, rate: rate, diff24h: diff24h)
        }
        return result
    }
}

//// MARK: - Events

extension API {
    func getAccountEvents(
        address: Address,
        beforeLt: Int64?,
        limit: Int
    ) async throws -> AccountEvents {
        let response = try await perform {
            try await $0.getAccountEvents(
                path: .init(accountId: address.toRaw()),
                query: .init(subjectOnly: true, beforeLt: beforeLt, limit: limit)
            ).ok.body.json
        }
        let events: [AccountEvent] = response.events.compactMap {
            guard let activityEvent = try? AccountEvent(accountEvent: $0) else { return nil }
            return activityEvent
        }
        return AccountEvents(
            address: address,
            events: events,
            startFrom: beforeLt ?? 0,
            nextFrom: response.nextFrom
        )
    }

    func getAccountJettonEvents(
        address: Address,
        jettonMasterAddress: Address,
        beforeLt: Int64?,
        limit: Int
    ) async throws -> AccountEvents {
        let response = try await perform {
            try await $0.getAccountJettonHistoryByID(
                path: .init(accountId: address.toRaw(), jettonId: jettonMasterAddress.toRaw()),
                query: .init(beforeLt: beforeLt, limit: limit)
            ).ok.body.json
        }
        let events: [AccountEvent] = response.events.compactMap {
            guard let activityEvent = try? AccountEvent(accountEvent: $0) else { return nil }
            return activityEvent
        }
        return AccountEvents(
            address: address,
            events: events,
            startFrom: beforeLt ?? 0,
            nextFrom: response.nextFrom
        )
    }

    func getEvent(
        address: Address,
        eventId: String
    ) async throws -> AccountEvent {
        let response = try await perform {
            try await $0.getAccountEvent(path: .init(accountId: address.toRaw(), eventId: eventId)).ok.body.json
        }
        return try AccountEvent(accountEvent: response)
    }
}

// MARK: - Wallet

extension API {
    func getSeqno(address: Address) async throws -> Int {
        let response = try await perform {
            try await $0.getAccountSeqno(path: .init(accountId: address.toRaw())).ok.body.json
        }
        return Int(response.seqno)
    }

    func getWalletInfo(address: Address) async throws -> WalletInfo {
        let response = try await perform {
            try await $0.getWalletInfo(path: .init(accountId: address.toRaw())).ok.body.json
        }
        return try WalletInfo(wallet: response)
    }

    func getWalletsByPubkeysBulk(publicKeys: [String], firebaseUserId: String?) async throws -> [(publicKey: String, wallets: [WalletInfo])] {
        let response: PubkeysWalletsBulkResponse = try await send(
            "getWalletsByPubkeysBulk",
            path: "/v2/pubkeys/wallets/_bulk",
            body: PubkeysWalletsBulkRequest(publicKeys: publicKeys),
            headers: firebaseUserId.map { ["F": $0] } ?? [:]
        )

        return response.items.map { item in
            (publicKey: item.publicKey, wallets: item.wallets.compactMap { try? WalletInfo(wallet: $0) })
        }
    }

    func emulateMessageWallet(
        boc: String,
        params: [EmulateMessageToWalletRequestParamsInner]?,
        currency: String? = nil
    ) async throws -> TonAPI.Components.Schemas.MessageConsequences {
        try await perform {
            try await $0.emulateMessageToWallet(
                query: .init(currency: currency),
                body: .json(.init(boc: boc, params: params))
            ).ok.body.json
        }
    }

    func sendTransaction(boc: String, headers: [String: String] = [:]) async throws {
        _ = try await perform(headers: headers) {
            try await $0.sendBlockchainMessage(body: .json(.init(boc: boc))).ok
        }
    }

    func sendTransactions(batch: [String]) async throws {
        _ = try await perform {
            try await $0.sendBlockchainMessage(body: .json(.init(batch: batch))).ok
        }
    }
}

// MARK: - NFTs

extension API {
    func getAccountNftItems(
        address: Address,
        collectionAddress: Address?,
        limit: Int?,
        offset: Int?,
        isIndirectOwnership: Bool
    ) async throws -> [NFT] {
        let response = try await perform {
            try await $0.getAccountNftItems(
                path: .init(accountId: address.toRaw()),
                query: .init(
                    collection: collectionAddress?.toRaw(),
                    limit: limit,
                    offset: offset,
                    indirectOwnership: isIndirectOwnership
                )
            ).ok.body.json
        }
        return response.nftItems.compactMap {
            try? NFT(nftItem: $0)
        }
    }

    func getNftItemsByAddresses(_ addresses: [Address]) async throws -> [NFT] {
        let response = try await perform {
            try await $0.getNftItemsByAddresses(
                body: .json(.init(accountIds: addresses.map { $0.toRaw() }))
            ).ok.body.json
        }
        return response.nftItems.compactMap {
            try? NFT(nftItem: $0)
        }
    }
}

// MARK: - Jettons

extension API {
    func resolveJetton(address: Address) async throws -> JettonInfo {
        let response = try await perform {
            try await $0.getJettonInfo(path: .init(accountId: address.toRaw())).ok.body.json
        }

        let verification: JettonInfo.Verification
        switch response.verification {
        case .none:
            verification = .none
        case .blacklist:
            verification = .blacklist
        case .whitelist:
            verification = .whitelist
        case .unknown:
            verification = .none
        case .graylist:
            verification = .graylist
        }

        let numerator: BigUInt? = {
            guard let numerator = response.scaledUi?.numerator else { return nil }

            return BigUInt(numerator)
        }()

        let denomenator: BigUInt? = {
            guard let denomenator = response.scaledUi?.denominator else { return nil }

            return BigUInt(denomenator)
        }()

        return try JettonInfo(
            isTransferable: true,
            hasCustomPayload: false,
            address: Address.parse(response.metadata.address),
            fractionDigits: Int(response.metadata.decimals) ?? 0,
            name: response.metadata.name,
            symbol: response.metadata.symbol,
            verification: verification,
            imageURL: URL(string: response.preview),
            numerator: numerator,
            denomenator: denomenator
        )
    }
}

// MARK: - Rates

extension API {
    func getRates(currencies: [Currency], jettons: [String]) async throws -> Rates {
        let tokens = ["GRAM", "USDT"] + jettons
        let response = try await perform {
            try await $0.getRates(query: .init(tokens: tokens, currencies: currencies.map { $0.code })).ok.body.json
        }

        return parseResponse(rates: response.rates.additionalProperties, jettons: jettons)
    }

    private func parseResponse(rates: [String: TonAPI.Components.Schemas.TokenRates], jettons: [String]) -> Rates {
        var tonRates = [Rates.Rate]()
        var usdtRates = [Rates.Rate]()
        var jettonsRates = [String: [Rates.Rate]]()

        for key in rates.keys {
            guard let rates = rates[key] else { continue }
            if key.lowercased() == TonInfo.symbol.lowercased() {
                guard let prices = rates.prices?.additionalProperties else { continue }
                let diff24h = rates.diff24h?.additionalProperties
                tonRates = prices.compactMap { price -> Rates.Rate? in
                    guard let currency = Currency(code: price.key) else { return nil }
                    let diff24h = diff24h?[price.key]
                    return Rates.Rate(currency: currency, rate: Decimal(price.value), diff24h: diff24h)
                }
                continue
            }
            if key.lowercased() == "usdt" {
                guard let prices = rates.prices?.additionalProperties else { continue }
                let diff24h = rates.diff24h?.additionalProperties
                usdtRates = prices.compactMap { price -> Rates.Rate? in
                    guard let currency = Currency(code: price.key) else { return nil }
                    let diff24h = diff24h?[price.key]
                    return Rates.Rate(currency: currency, rate: Decimal(price.value), diff24h: diff24h)
                }
                continue
            }
            guard jettons.contains(where: { $0.lowercased() == key.lowercased() }) else { continue }
            guard let prices = rates.prices?.additionalProperties else { continue }
            let diff24h = rates.diff24h?.additionalProperties
            let jettonRates: [Rates.Rate] = prices.compactMap { price -> Rates.Rate? in
                guard let currency = Currency(code: price.key) else { return nil }
                let diff24h = diff24h?[price.key]
                return Rates.Rate(currency: currency, rate: Decimal(price.value), diff24h: diff24h)
            }
            jettonsRates[key] = jettonRates
        }

        return Rates(
            ton: tonRates,
            usdt: usdtRates,
            jettonRates: jettonsRates
        )
    }
}

// MARK: - DNS

extension API {
    enum DNSError: Swift.Error {
        case noWalletData
    }

    func resolveDomainName(_ domainName: String) async throws -> FriendlyAddress {
        let response = try await perform {
            try await $0.dnsResolve(path: .init(domainName: domainName)).ok.body.json
        }
        guard let wallet = response.wallet else {
            throw DNSError.noWalletData
        }

        let address = try Address.parse(wallet.address)
        return FriendlyAddress(address: address, bounceable: !wallet.account.isWallet)
    }

    func getDomainExpirationDate(_ domainName: String) async throws -> Date? {
        let response = try await perform {
            try await $0.getDnsInfo(path: .init(domainName: domainName)).ok.body.json
        }
        guard let expiringAt = response.expiringAt else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(integerLiteral: Int64(expiringAt)))
    }
}

extension API {
    enum APIError: Swift.Error {
        case incorrectURL
        case incorrectResponse
        case serverError(statusCode: Int)
    }

    private struct ChartResponse: Decodable {
        let coordinates: [Coordinate]

        enum CodingKeys: String, CodingKey {
            case points
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let points = try container.decode([[Double]].self, forKey: .points)
            let coordinates = points.compactMap { item -> Coordinate? in
                guard item.count == 2 else { return nil }
                return Coordinate(x: item[0], y: item[1])
            }
            self.coordinates = coordinates
        }
    }

    func getChart(token: String, period: Period, currency: Currency) async throws -> [Coordinate] {
        guard var components = await URLComponents(string: configuration.tonapiV2Endpoint) else {
            throw APIError.incorrectURL
        }
        components.path = "/v2/rates/chart"
        components.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "currency", value: currency.code),
            URLQueryItem(name: "start_date", value: "\(Int(period.startDate.timeIntervalSince1970))"),
            URLQueryItem(name: "end_date", value: "\(Int(period.endDate.timeIntervalSince1970))"),
        ]

        guard let url = components.url else {
            throw APIError.incorrectURL
        }
        let token = await configuration.tonApiV2Key
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = (response as? HTTPURLResponse) else {
            throw APIError.incorrectResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        let chartResponse = try JSONDecoder().decode(ChartResponse.self, from: data)
        return chartResponse.coordinates.reversed()
    }
}

// MARK: - Jetton

extension API {
    func getCustomPayload(address: Address, jettonAddress: Address) async throws -> JettonTransferPayload {
        let response = try await perform {
            try await $0.getJettonTransferPayload(
                path: .init(accountId: address.toRaw(), jettonId: jettonAddress.toRaw())
            ).ok.body.json
        }
        return try JettonTransferPayload(customPayload: response.customPayload, stateInit: response.stateInit)
    }
}

// MARK: - Staking

extension API {
    func getPools(address: Address) async throws -> [StackingPoolInfo] {
        let response = try await perform {
            try await $0.getStakingPools(
                query: .init(availableFor: address.toRaw(), includeUnverified: false)
            ).ok.body.json
        }
        return response.pools.compactMap {
            try? StackingPoolInfo(accountStakingInfo: $0, implementations: response.implementations.additionalProperties)
        }
    }

    func getNominators(address: Address) async throws -> [AccountStackingInfo] {
        let response = try await perform {
            try await $0.getAccountNominatorsPools(path: .init(accountId: address.toRaw())).ok.body.json
        }
        return response.pools.compactMap { try? AccountStackingInfo(accountStakingInfo: $0) }
    }
}

// MARK: - Blockchain

extension API {
    func getWalletAddress(jettonMaster: String, owner: String) async throws -> Address {
        let response = try await perform {
            try await $0.execGetMethodForBlockchainAccount(
                path: .init(accountId: jettonMaster, methodName: "get_wallet_address"),
                query: .init(args: [owner])
            ).ok.body.json
        }

        guard let decoded = response.decoded?.value as? [String: (any Sendable)?],
              let jettonWalletAddress = decoded["jetton_wallet_address"] as? String
        else {
            throw APIError.incorrectResponse
        }

        return try Address.parse(jettonWalletAddress)
    }
}

// MARK: - TonConnect

extension API {
    func getTonProofToken(wallet: Wallet, tonProof: TonConnect.TonProof) async throws -> String {
        let builder = Builder()
        try wallet.stateInit.storeTo(builder: builder)
        let stateInit = try builder.endCell().toBoc().base64EncodedString()
        let signature = try tonProof.signature.signature().base64EncodedString()
        let walletAddress = try wallet.address.toRaw()

        let response = try await perform {
            try await $0.tonConnectProof(body: .json(.init(
                address: walletAddress,
                proof: .init(
                    timestamp: Int64(tonProof.timestamp),
                    domain: .init(lengthBytes: Int32(tonProof.domain.lengthBytes), value: tonProof.domain.value),
                    signature: signature,
                    payload: tonProof.payload,
                    stateInit: stateInit
                )
            ))).ok.body.json
        }
        return response.token
    }

    func getTonconnectPayload() async throws -> String {
        let response = try await perform {
            try await $0.getTonConnectPayload().ok.body.json
        }
        return response.payload
    }
}

// MARK: - Migration

extension API {
    func prepareMigration(
        from: String,
        to: String,
        currency: Currency,
        publicKey: String,
        gasPayer: MigrationGasPayer = .self
    ) async throws -> MigrationPrepareResponseBody {
        do {
            return try await send(
                "prepareMigration",
                path: "/v2/migration/prepare",
                body: MigrationPrepareRequestBody(
                    from: from,
                    to: to,
                    currency: currency.code,
                    publicKey: publicKey,
                    gasPayer: gasPayer
                )
            )
        } catch let error as TonAPIError {
            guard gasPayer == .self,
                  let response = MigrationPrepareResponseBody(insufficientTonError: error)
            else {
                throw error
            }
            return response
        }
    }

    func getMigrationWallets(
        accountIds: [String],
        currency: Currency
    ) async throws -> TonAPI.Components.Schemas.MigrationWallets {
        try await perform {
            try await $0.getMigrationWallets(
                query: .init(currencies: [currency.code]),
                body: .json(.init(accountIds: accountIds))
            ).ok.body.json
        }
    }
}

// MARK: - Gasless

extension API {
    func getGaslessRelayAddress() async throws -> Address {
        let response = try await perform {
            try await $0.gaslessConfig().ok.body.json
        }
        return try Address.parse(response.relayAddress)
    }
}

// MARK: - Time

extension API {
    func getTime() async throws -> TimeInterval {
        let response = try await perform {
            try await $0.getRawTime().ok.body.json
        }
        return TimeInterval(response.time)
    }
}

// MARK: - Status

extension API {
    func getStatus() async throws -> Int {
        let response = try await perform {
            try await $0.status().ok.body.json
        }
        return Int(response.indexingLatency)
    }
}
