import Foundation
import TonAPI
import TonSwift
import BigInt
import OpenAPIRuntime

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

public struct API {

  private let hostProvider: APIHostProvider
  private let urlSession: URLSession
  private let configuration: Configuration
  private let requestCreationQueue: DispatchQueue
  
  init(hostProvider: APIHostProvider,
       urlSession: URLSession,
       configuration: Configuration,
       requestCreationQueue: DispatchQueue) {
    self.hostProvider = hostProvider
    self.urlSession = urlSession
    self.configuration = configuration
    self.requestCreationQueue = requestCreationQueue
  }
  
  private func createRequest<T>(requestCreation: () -> RequestBuilder<T>) async throws -> RequestBuilder<T> {
    let apiKey = await configuration.tonApiV2Key
    let hostUrl = await hostProvider.basePath
    return requestCreationQueue.sync {
      TonAPIAPI.basePath = hostUrl
      var request = requestCreation()
      request = request.addHeader(name: "Authorization", value: "Bearer \(apiKey)")
      return request
    }
  }
}

// MARK: - Account

extension API {
  func getAccountInfo(address: String) async throws -> Account {
    let request = try await createRequest {
      return AccountsAPI.getAccountWithRequestBuilder(accountId: address)
    }
    let response = try await request.execute().body
    return try Account(account: response)
  }
  
  func getAccountJettonsBalances(address: Address, currencies: [Currency]) async throws -> [JettonBalance] {
    let request = try await createRequest {
      return AccountsAPI.getAccountJettonsBalancesWithRequestBuilder(
        accountId: address.toRaw(),
        currencies: currencies.map { $0.code },
        supportedExtensions: ["custom_payload"]
      )
    }
    let response = try await request.execute().body
    let balances = response.balances
      .compactMap { jetton in
        do {
          let quantity = BigUInt(stringLiteral: jetton.balance)
          let walletAddress = try Address.parse(jetton.walletAddress.address)
          let rates = mapJettonRates(rates: jetton.price)
          let jettonInfo = try JettonInfo(jettonPreview: jetton.jetton, extensions: jetton.extensions)
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
    let request = try await createRequest {
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
    let request = try await createRequest {
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
    let request = try await createRequest {
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
    let request = try await createRequest {
      return WalletAPI.getAccountSeqnoWithRequestBuilder(accountId: address.toRaw())
    }
    
    let response = try await request.execute().body
    return response.seqno
  }
  
  func emulateMessageWallet(boc: String) async throws -> MessageConsequences {
    let request = try await createRequest {
      return EmulationAPI.emulateMessageToWalletWithRequestBuilder(
        emulateMessageToWalletRequest: EmulateMessageToWalletRequest(boc: boc)
      )
    }
    
    let response = try await request.execute().body
    return response
  }
  
  func sendTransaction(boc: String) async throws {
    let request = try await createRequest {
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
    let request = try await createRequest {
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
    let request = try await createRequest {
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
    let request = try await createRequest {
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
      isTransferable: true,
      hasCustomPayload: false,
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
    let request = try await createRequest {
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
    let request = try await createRequest {
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
    let request = try await createRequest {
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
    guard var components = await URLComponents(string: configuration.tonapiV2Endpoint) else { return [] }
    components.path = "/v2/rates/chart"
    components.queryItems = [
      URLQueryItem(name: "token", value: token),
      URLQueryItem(name: "currency", value: currency.code),
      URLQueryItem(name: "start_date", value: "\(Int(period.startDate.timeIntervalSince1970))"),
      URLQueryItem(name: "end_date", value: "\(Int(period.endDate.timeIntervalSince1970))")
    ]
    
    guard let url = components.url else { return [] }
    let token = await configuration.tonApiV2Key
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

// MARK: - Jetton

extension API {
  func getCustomPayload(address: Address, jettonAddress: Address) async throws -> JettonTransferPayload {
    let request = try await createRequest {
      return JettonsAPI.getJettonTransferPayloadWithRequestBuilder(
        accountId: address.toRaw(),
        jettonId: jettonAddress.toRaw()
      )
    }
    let response = try await request.execute().body
    return try JettonTransferPayload(customPayload: response.customPayload, stateInit: response.stateInit)
  }
}
  
// MARK: - Staking

extension API {
  func getPools(address: Address) async throws -> [StackingPoolInfo]{
    let request = try await createRequest {
      return StakingAPI.getStakingPoolsWithRequestBuilder(
        availableFor: address.toRaw(),
        includeUnverified: false
      )
    }
    
    let response = try await request.execute().body
    let result = response.pools.compactMap {
      try? StackingPoolInfo(accountStakingInfo: $0, implementations: response.implementations)
    }
    return result
  }
  
  func getNominators(address: Address) async throws -> [AccountStackingInfo] {
    let request = try await createRequest {
      return StakingAPI.getAccountNominatorsPoolsWithRequestBuilder(accountId: address.toRaw())
    }
    
    let response = try await request.execute().body
    let result = response.pools.compactMap { try? AccountStackingInfo(accountStakingInfo: $0) }
    return result
  }
  
  func getPoolInfo(poolAddress: Address) async throws -> StackingPoolInfo {
    let request = try await createRequest {
      return StakingAPI.getStakingPoolInfoWithRequestBuilder(accountId: poolAddress.toRaw())
    }
    let response = try await request.execute().body
    let result = try StackingPoolInfo(accountStakingInfo: response.pool, implementations: [response.pool.implementation.rawValue: response.implementation])
    return result
  }
}

// MARK: - Blockchain

extension API {
  func getWalletAddress(jettonMaster: String, owner: String) async throws -> Address {
    let request = try await createRequest {
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

// MARK: - TonConnect
extension API {
  func getTonProofToken(wallet: Wallet, tonProof: TonConnect.TonProof) async throws -> String {
    let builder = Builder()
    try wallet.stateInit.storeTo(builder: builder)
    let stateInit = try builder.endCell().toBoc().base64EncodedString()
    let signature = try tonProof.signature.signature().base64EncodedString()
    let walletAddress = try wallet.address.toRaw()
    
    let request = try await createRequest {
      return WalletAPI.tonConnectProofWithRequestBuilder(
        tonConnectProofRequest: TonConnectProofRequest(
          address: walletAddress,
          proof: TonConnectProofRequestProof(
            timestamp: Int64(tonProof.timestamp),
            domain: TonConnectProofRequestProofDomain(
              lengthBytes: Int(tonProof.domain.lengthBytes),
              value: tonProof.domain.value
            ),
            signature: signature,
            payload: tonProof.payload,
            stateInit: stateInit
          )
        )
      )
    }

    let response = try await request.execute().body
    return response.token
  }
  
  func getTonconnectPayload() async throws -> String {
    let request = try await createRequest {
      return ConnectAPI.getTonConnectPayloadWithRequestBuilder()
    }
    let response = try await request.execute().body
    return response.payload
  }
}

// MARK: - Time
extension API {
  func getTime() async throws -> TimeInterval {
    let request = try await createRequest {
      return LiteServerAPI.getRawTimeWithRequestBuilder()
    }
    
    let response = try await request.execute().body
    return TimeInterval(response.time)
  }
}

// MARK: - Status
extension API {
  func getStatus() async throws -> Int {
    let request = try await createRequest {
      return BlockchainAPI.statusWithRequestBuilder()
    }
    let response = try await request.execute().body
    return response.indexingLatency
  }
}
