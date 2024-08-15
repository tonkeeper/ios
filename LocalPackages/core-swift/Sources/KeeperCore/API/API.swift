import Foundation
import TonAPI
import TonSwift
import BigInt
import OpenAPIRuntime

protocol APIHostProvider {
  var basePath: String { get async }
}

struct MainnetAPIHostProvider: APIHostProvider {
  private let remoteConfigurationStore: ConfigurationStore
  
  init(remoteConfigurationStore: ConfigurationStore) {
    self.remoteConfigurationStore = remoteConfigurationStore
  }
  
  var basePath: String {
    get async {
      await (try? remoteConfigurationStore.getConfiguration().tonapiV2Endpoint) ?? ""
    }
  }
}

struct TestnetAPIHostProvider: APIHostProvider {
  private let remoteConfigurationStore: ConfigurationStore
  
  init(remoteConfigurationStore: ConfigurationStore) {
    self.remoteConfigurationStore = remoteConfigurationStore
  }
  
  var basePath: String {
    get async {
      await (try? remoteConfigurationStore.getConfiguration().tonapiTestnetHost) ?? ""
    }
  }
}

public actor APIRequestBuilderSerialActor {
  private var previousTask: Task<Any, Swift.Error>?
  
  public init() {}
  
  public func addTask<T>(block: @Sendable @escaping () async throws -> T) async throws -> T {
    previousTask = Task { [previousTask] in
      let _ = await previousTask?.result
      return try await block()
    }
    return try await previousTask!.value as! T
  }
}

struct API {
  private let hostProvider: APIHostProvider
  private let urlSession: URLSession
  private let configurationStore: ConfigurationStore
  private let requestBuilderActor: APIRequestBuilderSerialActor
  
  init(hostProvider: APIHostProvider,
       urlSession: URLSession,
       configurationStore: ConfigurationStore,
       requestBuilderActor: APIRequestBuilderSerialActor) {
    self.hostProvider = hostProvider
    self.urlSession = urlSession
    self.configurationStore = configurationStore
    self.requestBuilderActor = requestBuilderActor
  }
  
  private func prepareAPIForRequest() async {
    async let apiKeyTask = ((try? await configurationStore.getConfiguration()) ?? .empty).tonApiV2Key
    async let hostUrlTask = await hostProvider.basePath
    let apiKey = await apiKeyTask
    let hostURL = await hostUrlTask
    TonAPIAPI.customHeaders = ["Authorization": "Bearer \(apiKey)"]
    TonAPIAPI.basePath = hostURL
  }
}

// MARK: - Account

extension API {
  func getAccountInfo(address: String) async throws -> Account {
    let request = try await requestBuilderActor.addTask(block: {
      await prepareAPIForRequest()
      return AccountsAPI.getAccountWithRequestBuilder(accountId: address)
    })
    
    let response = try await request.execute().body
    return try Account(account: response)
  }
  
  func getAccountJettonsBalances(address: Address, currencies: [Currency]) async throws -> [JettonBalance] {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return AccountsAPI.getAccountJettonsBalancesWithRequestBuilder(
        accountId: address.toRaw(),
        currencies: currencies.map { $0.code }
      )
    }
    
    let response = try await request.execute().body
    let balances = response.balances
      .compactMap { jetton in
        do {
          let quantity = BigUInt(stringLiteral: jetton.balance)
          let walletAddress = try Address.parse(jetton.walletAddress.address)
          let rates = mapJettonRates(rates: jetton.price)
          let jettonInfo = try JettonInfo(jettonPreview: jetton.jetton)
          let jettonItem = JettonItem(jettonInfo: jettonInfo, walletAddress: walletAddress)
          let jettonBalance = JettonBalance(item: jettonItem, quantity: quantity, rates: rates)
          return jettonBalance
        } catch {
          return nil
        }
      }
    return balances
  }
  
  private func mapJettonRates(rates: TokenRates?) -> [Currency: Rates.Rate] {
    var result = [Currency: Rates.Rate]()
    rates?.prices?.forEach { currencyCode, value in
      guard let currency = Currency(code: currencyCode) else { return }
      let rate = Decimal(value)
      let diff24h = rates?.diff24h?.first(where: { $0.key == currencyCode })?.value
      result[currency] = Rates.Rate(currency: currency, rate: rate, diff24h: diff24h)
    }
    return result
  }
}

//// MARK: - Events

extension API {
  func getAccountEvents(address: Address,
                        beforeLt: Int64?,
                        limit: Int) async throws -> AccountEvents {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return AccountsAPI.getAccountEventsWithRequestBuilder(
        accountId: address.toRaw(),
        limit: limit,
        beforeLt: beforeLt,
        startDate: nil,
        endDate: nil
      )
    }
    let response = try await request.execute().body
    let events: [AccountEvent] = response.events.compactMap {
      guard let activityEvent = try? AccountEvent(accountEvent: $0) else { return nil }
      return activityEvent
    }
    return AccountEvents(address: address,
                         events: events,
                         startFrom: beforeLt ?? 0,
                         nextFrom: response.nextFrom)
  }
  
  func getAccountJettonEvents(address: Address,
                              jettonInfo: JettonInfo,
                              beforeLt: Int64?,
                              limit: Int) async throws -> AccountEvents {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return AccountsAPI.getAccountJettonHistoryByIDWithRequestBuilder(
        accountId: address.toRaw(),
        jettonId: jettonInfo.address.toRaw(),
        limit: limit,
        beforeLt: beforeLt,
        startDate: nil,
        endDate: nil
      )
    }
    
    let response = try await request.execute().body
    let events: [AccountEvent] = response.events.compactMap {

      guard let activityEvent = try? AccountEvent(accountEvent: $0) else { return nil }
      return activityEvent
    }
    return AccountEvents(address: address,
                          events: events,
                          startFrom: beforeLt ?? 0,
                          nextFrom: response.nextFrom)
  }
  
  func getEvent(address: Address,
                eventId: String) async throws -> AccountEvent {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return AccountsAPI.getAccountEventWithRequestBuilder(
        accountId: address.toRaw(),
        eventId: eventId
      )
    }
    let response = try await request.execute().body
    return try AccountEvent(accountEvent: response)
  }
}

// MARK: - Wallet

extension API {
  func getSeqno(address: Address) async throws -> Int {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return WalletAPI.getAccountSeqnoWithRequestBuilder(accountId: address.toRaw())
    }
    
    let response = try await request.execute().body
    return response.seqno
  }
  
  func emulateMessageWallet(boc: String) async throws -> MessageConsequences {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return EmulationAPI.emulateMessageToWalletWithRequestBuilder(
        emulateMessageToWalletRequest: EmulateMessageToWalletRequest(boc: boc)
      )
    }
    
    let response = try await request.execute().body
    return response
  }
  
  func sendTransaction(boc: String) async throws {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return BlockchainAPI.sendBlockchainMessageWithRequestBuilder(
        sendBlockchainMessageRequest: SendBlockchainMessageRequest(
          boc: boc
        )
      )
    }
    try await request.execute()
  }
}

// MARK: - NFTs

extension API {
  func getAccountNftItems(address: Address,
                          collectionAddress: Address?,
                          limit: Int?,
                          offset: Int?,
                          isIndirectOwnership: Bool) async throws -> [NFT] {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return AccountsAPI.getAccountNftItemsWithRequestBuilder(
        accountId: address.toRaw(),
        collection: collectionAddress?.toRaw(),
        limit: limit,
        offset: offset,
        indirectOwnership: isIndirectOwnership
      )
    }
    
    let response = try await request.execute().body
    let collectibles = response.nftItems.compactMap {
      try? NFT(nftItem: $0)
    }
    
    return collectibles
  }
  
  func getNftItemsByAddresses(_ addresses: [Address]) async throws -> [NFT] {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return NFTAPI.getNftItemsByAddressesWithRequestBuilder(
        getAccountsRequest: GetAccountsRequest(
          accountIds: addresses.map { $0.toRaw() }
        )
      )
    }
    
    let response = try await request.execute().body
    let nfts = response.nftItems.compactMap {
      try? NFT(nftItem: $0)
    }
    return nfts
  }
}

// MARK: - Jettons

extension API {
  func resolveJetton(address: Address) async throws -> JettonInfo {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return JettonsAPI.getJettonInfoWithRequestBuilder(accountId: address.toRaw())
    }
    let response = try await request.execute().body
    
    let verification: JettonInfo.Verification
    switch response.verification {
    case ._none:
      verification = .none
    case .blacklist:
      verification = .blacklist
    case .whitelist:
      verification = .whitelist
    case .unknownDefaultOpenApi:
      verification = .none
    }
    
    return JettonInfo(
      address: try Address.parse(response.metadata.address),
      fractionDigits: Int(response.metadata.decimals) ?? 0,
      name: response.metadata.name,
      symbol: response.metadata.symbol,
      verification: verification,
      imageURL: URL(string: response.metadata.image ?? "")
    )
  }
}

// MARK: - Rates

extension API {
  func getRates(jettons: [JettonInfo],
                currencies: [Currency]) async throws -> Rates {
    let tokens = CollectionOfOne(TonInfo.symbol.lowercased()) + jettons.map { $0.address.toRaw() }
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return RatesAPI.getRatesWithRequestBuilder(
        tokens: tokens,
        currencies: currencies.map { $0.code }
      )
    }
    
    let response = try await request.execute().body
    
    return parseResponse(rates: response.rates, jettons: jettons)
  }
  
  private func parseResponse(rates: [String: TonAPI.TokenRates],
                             jettons: [JettonInfo]) -> Rates {
    var tonRates = [Rates.Rate]()
    var jettonsRates = [Rates.JettonRate]()
    for key in rates.keys {
      guard let jettonRates = rates[key] else { continue }
      if key.lowercased() == TonInfo.symbol.lowercased() {
        guard let prices = jettonRates.prices else { continue }
        let diff24h = jettonRates.diff24h
        tonRates = prices.compactMap { price -> Rates.Rate? in
          guard let currency = Currency(code: price.key) else { return nil }
          let diff24h = diff24h?[price.key]
          return Rates.Rate(currency: currency, rate: Decimal(price.value), diff24h: diff24h)
        }
        continue
      }
      guard let jettonInfo = jettons.first(where: { $0.address.toRaw() == key.lowercased()}) else { continue }
      guard let prices = jettonRates.prices else { continue }
      let diff24h = jettonRates.diff24h
      let rates: [Rates.Rate] = prices.compactMap { price -> Rates.Rate? in
        guard let currency = Currency(code: price.key) else { return nil }
        let diff24h = diff24h?[price.key]
        return Rates.Rate(currency: currency, rate: Decimal(price.value), diff24h: diff24h)
      }
      jettonsRates.append(.init(jettonInfo: jettonInfo, rates: rates))
      
    }
    return Rates(ton: tonRates, jettonsRates: jettonsRates)
  }
}

// MARK: - DNS

extension API {
  enum DNSError: Swift.Error {
    case noWalletData
  }
  
  func resolveDomainName(_ domainName: String) async throws -> FriendlyAddress {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return DNSAPI.dnsResolveWithRequestBuilder(domainName: domainName)
    }

    let response = try await request.execute().body
    guard let wallet = response.wallet else {
      throw DNSError.noWalletData
    }
    
    let address = try Address.parse(wallet.address)
    return FriendlyAddress(address: address, bounceable: !wallet.account.isWallet)
  }
  
  func getDomainExpirationDate(_ domainName: String) async throws -> Date? {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return DNSAPI.getDnsInfoWithRequestBuilder(domainName: domainName)
    }
    
    let response = try await request.execute().body
    guard let expiringAt = response.expiringAt else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(integerLiteral: Int64(expiringAt)))
  }
}

extension API {
  
  enum APIError: Swift.Error {
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
    let configuration = try await configurationStore.getConfiguration()
    guard var components = URLComponents(string: configuration.tonapiV2Endpoint) else { return [] }
    components.path = "/v2/rates/chart"
    components.queryItems = [
      URLQueryItem(name: "token", value: token),
      URLQueryItem(name: "currency", value: currency.code),
      URLQueryItem(name: "start_date", value: "\(Int(period.startDate.timeIntervalSince1970))"),
      URLQueryItem(name: "end_date", value: "\(Int(period.endDate.timeIntervalSince1970))")
    ]
    
    guard let url = components.url else { return [] }
    let token = try await configurationStore.getConfiguration().tonApiV2Key
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = (response as? HTTPURLResponse) else {
      throw APIError.incorrectResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.serverError(statusCode: httpResponse.statusCode)
    }
    let chartResponse = try JSONDecoder().decode(ChartResponse.self, from: data)
    return chartResponse.coordinates.reversed()
  }
}

// MARK: - Blockchain

extension API {
  func getWalletAddress(jettonMaster: String, owner: String) async throws -> Address {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return BlockchainAPI.execGetMethodForBlockchainAccountWithRequestBuilder(
        accountId: jettonMaster,
        methodName: "get_wallet_address",
        args: [owner]
      )
    }

    let response = try await request.execute().body
    
    guard let decoded = response.decoded?.value as? [String: Any],
          let jettonWalletAddress = decoded["jetton_wallet_address"] as? String else {
      throw APIError.incorrectResponse
    }
    
    return try Address.parse(jettonWalletAddress)
  }
}

// MARK: - Time
extension API {
  func getTime() async throws -> TimeInterval {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return LiteServerAPI.getRawTimeWithRequestBuilder()
    }
    
    let response = try await request.execute().body
    return TimeInterval(response.time)
  }
}

// MARK: - Status
extension API {
  func getStatus() async throws -> Int {
    let request = try await requestBuilderActor.addTask {
      await prepareAPIForRequest()
      return BlockchainAPI.statusWithRequestBuilder()
    }
    let response = try await request.execute().body
    return response.indexingLatency
  }
}
