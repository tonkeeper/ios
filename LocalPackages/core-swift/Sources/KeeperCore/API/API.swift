import Foundation
import TonAPI
import TonSwift
import BigInt
import OpenAPIRuntime

struct API {
  private let tonAPIClient: TonAPI.Client
  private let urlSession: URLSession
  private let configurationStore: ConfigurationStore
  
  init(tonAPIClient: TonAPI.Client,
       urlSession: URLSession,
       configurationStore: ConfigurationStore) {
    self.tonAPIClient = tonAPIClient
    self.urlSession = urlSession
    self.configurationStore = configurationStore
  }
}

// MARK: - Account

extension API {
  func getAccountInfo(address: String) async throws -> Account {
    let response = try await tonAPIClient
      .getAccount(.init(path: .init(account_id: address)))
    return try Account(account: try response.ok.body.json)
  }
  
  func getAccountJettonsBalances(address: Address, currencies: [Currency]) async throws -> [JettonBalance] {
    let currenciesString = currencies.map { $0.code }.joined(separator: ",")
    let response = try await tonAPIClient
      .getAccountJettonsBalances(path: .init(account_id: address.toRaw()), query: .init(currencies: currenciesString))
    return try response.ok.body.json.balances
      .compactMap { jetton in
        do {
          let quantity = BigUInt(stringLiteral: jetton.balance)
          let walletAddress = try Address.parse(jetton.wallet_address.address)
          let rates = mapJettonRates(rates: jetton.price)
          let jettonInfo = try JettonInfo(jettonPreview: jetton.jetton)
          let jettonItem = JettonItem(jettonInfo: jettonInfo, walletAddress: walletAddress)
          let jettonBalance = JettonBalance(item: jettonItem, quantity: quantity, rates: rates)
          return jettonBalance
        } catch {
          return nil
        }
      }
  }
  
  private func mapJettonRates(rates: Components.Schemas.TokenRates?) -> [Currency: Rates.Rate] {
    var result = [Currency: Rates.Rate]()
    rates?.prices?.additionalProperties.forEach { currencyCode, value in
      guard let currency = Currency(code: currencyCode) else { return }
      let rate = Decimal(value)
      let diff24h = rates?.diff_24h?.additionalProperties.first(where: { $0.key == currencyCode })?.value
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
    let response = try await tonAPIClient.getAccountEvents(
      path: .init(account_id: address.toRaw()),
      query: .init(before_lt: beforeLt,
                   limit: limit,
                   start_date: nil,
                   end_date: nil)
    )
    let entity = try response.ok.body.json
    let events: [AccountEvent] = entity.events.compactMap {
      guard let activityEvent = try? AccountEvent(accountEvent: $0) else { return nil }
      return activityEvent
    }
    return AccountEvents(address: address,
                          events: events,
                          startFrom: beforeLt ?? 0,
                          nextFrom: entity.next_from)
  }
  
  func getAccountJettonEvents(address: Address,
                              jettonInfo: JettonInfo,
                              beforeLt: Int64?,
                              limit: Int) async throws -> AccountEvents {
    let response = try await tonAPIClient.getAccountJettonHistoryByID(
      path: .init(account_id: address.toRaw(),
                  jetton_id: jettonInfo.address.toRaw()),
      query: .init(before_lt: beforeLt,
                   limit: limit,
                   start_date: nil,
                   end_date: nil)
    )
    let entity = try response.ok.body.json
    let events: [AccountEvent] = entity.events.compactMap {
      guard let activityEvent = try? AccountEvent(accountEvent: $0) else { return nil }
      return activityEvent
    }
    return AccountEvents(address: address,
                          events: events,
                          startFrom: beforeLt ?? 0,
                          nextFrom: entity.next_from)
  }
  
  func getEvent(address: Address,
                eventId: String) async throws -> AccountEvent {
    let response = try await tonAPIClient
      .getAccountEvent(path: .init(account_id: address.toRaw(),
                                   event_id: eventId))
    return try AccountEvent(accountEvent: try response.ok.body.json)
  }
}

// MARK: - Wallet

extension API {
  func getSeqno(address: Address) async throws -> Int {
    let response = try await tonAPIClient
      .getAccountSeqno(path: .init(account_id: address.toRaw()))
    return try response.ok.body.json.seqno
  }
  
  func emulateMessageWallet(boc: String) async throws -> Components.Schemas.MessageConsequences {
    let response = try await tonAPIClient
      .emulateMessageToWallet(body: .json(.init(boc: boc)))
    return try response.ok.body.json
  }
  
  func sendTransaction(boc: String) async throws {
    let response = try await tonAPIClient
      .sendBlockchainMessage(body: .json(.init(boc: boc)))
    _ = try response.ok
  }
}

// MARK: - NFTs

extension API {
  func getAccountNftItems(address: Address,
                          collectionAddress: Address?,
                          limit: Int?,
                          offset: Int?,
                          isIndirectOwnership: Bool) async throws -> [NFT] {
    let response = try await tonAPIClient.getAccountNftItems(
      path: .init(account_id: address.toRaw()),
      query: .init(collection: collectionAddress?.toRaw(),
                   limit: limit,
                   offset: offset,
                   indirect_ownership: isIndirectOwnership)
    )
    let entity = try response.ok.body.json
    let collectibles = entity.nft_items.compactMap {
      try? NFT(nftItem: $0)
    }
    
    return collectibles
  }
  
  func getNftItemsByAddresses(_ addresses: [Address]) async throws -> [NFT] {
    let response = try await tonAPIClient
      .getNftItemsByAddresses(
        .init(
          body: .json(.init(account_ids: addresses.map { $0.toRaw() })))
      )
    let entity = try response.ok.body.json
    let nfts = entity.nft_items.compactMap {
      try? NFT(nftItem: $0)
    }
    return nfts
  }
}

// MARK: - Jettons

extension API {
  func resolveJetton(address: Address) async throws -> JettonInfo {
    let response = try await tonAPIClient.getJettonInfo(
      Operations.getJettonInfo.Input(
        path: Operations.getJettonInfo.Input.Path(
          account_id: address.toRaw()
        )
      )
    )
    let entity = try response.ok.body.json
    let verification: JettonInfo.Verification
    switch entity.verification {
    case .none:
      verification = .none
    case .blacklist:
      verification = .blacklist
    case .whitelist:
      verification = .whitelist
    }
    
    return JettonInfo(
      address: try Address.parse(entity.metadata.address),
      fractionDigits: Int(entity.metadata.decimals) ?? 0,
      name: entity.metadata.name,
      symbol: entity.metadata.symbol,
      verification: verification,
      imageURL: URL(string: entity.metadata.image ?? "")
    )
  }
}

// MARK: - Rates

extension API {
  func getRates(jettons: [JettonInfo],
                currencies: [Currency]) async throws -> Rates {
    let requestTokens = ([TonInfo.symbol.lowercased()] + jettons.map { $0.address.toRaw() })
      .joined(separator: ",")
    let requestCurrencies = currencies.map { $0.code }
      .joined(separator: ",")
    let response = try await tonAPIClient
      .getRates(query: .init(tokens: requestTokens, currencies: requestCurrencies))
    let entity = try response.ok.body.json
    return parseResponse(rates: entity.rates.additionalProperties, jettons: jettons)
  }
  
  private func parseResponse(rates: [String: Components.Schemas.TokenRates],
                             jettons: [JettonInfo]) -> Rates {
    var tonRates = [Rates.Rate]()
    var jettonsRates = [Rates.JettonRate]()
    for key in rates.keys {
      guard let jettonRates = rates[key] else { continue }
      if key.lowercased() == TonInfo.symbol.lowercased() {
        guard let prices = jettonRates.prices?.additionalProperties else { continue }
        let diff24h = jettonRates.diff_24h?.additionalProperties
        tonRates = prices.compactMap { price -> Rates.Rate? in
          guard let currency = Currency(code: price.key) else { return nil }
          let diff24h = diff24h?[price.key]
          return Rates.Rate(currency: currency, rate: Decimal(price.value), diff24h: diff24h)
        }
        continue
      }
      guard let jettonInfo = jettons.first(where: { $0.address.toRaw() == key.lowercased()}) else { continue }
      guard let prices = jettonRates.prices?.additionalProperties else { continue }
      let diff24h = jettonRates.diff_24h?.additionalProperties
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
    let response = try await tonAPIClient.dnsResolve(path: .init(domain_name: domainName))
    let entity = try response.ok.body.json
    guard let wallet = entity.wallet else {
      throw DNSError.noWalletData
    }
    
    let address = try Address.parse(wallet.address)
    return FriendlyAddress(address: address, bounceable: !wallet.is_wallet)
  }
  
  func getDomainExpirationDate(_ domainName: String) async throws -> Date? {
    let response = try await tonAPIClient.getDnsInfo(path: .init(domain_name: domainName))
    let entity = try response.ok.body.json
    guard let expiringAt = entity.expiring_at else { return nil }
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
    let response = try await tonAPIClient.execGetMethodForBlockchainAccount(path: .init(account_id: jettonMaster, method_name: "get_wallet_address"), query: .init(args: [owner])
    )
    
    let decoded = try response.ok.body.json.decoded?.value.unsafelyUnwrapped as AnyObject
    
    guard let jettonWalletAddress = decoded["jetton_wallet_address"] as? String else {
      throw APIError.incorrectResponse
    }
    
    return try Address.parse(jettonWalletAddress)
  }
}

// MARK: - Time
extension API {
  func getTime() async throws -> TimeInterval {
    let response = try await tonAPIClient.getRawTime(Operations.getRawTime.Input())
    let entity = try response.ok.body.json
    return TimeInterval(entity.time)
  }
}

// MARK: - Staking

extension API {
  func getStakingPools(address: Address, includeUnverified: Bool) async throws -> [StakingPool] {
    let input: Operations.getStakingPools.Input = .init(
      query: .init(
        available_for: address.toRaw(),
        include_unverified: includeUnverified
      )
    )
    
    let response = try await tonAPIClient.getStakingPools(input)
    let jsonPayload = try response.ok.body.json
    
    return parceJsonPayload(jsonPayload)
  }
  
  private func parceJsonPayload(
    _ payload: Operations.getStakingPools.Output.Ok.Body.jsonPayload
  ) -> [StakingPool] {
    let poolTypes: [StakingPool.Implementation] = StakingPool.Implementation.Kind
      .allCases
      .compactMap { kind in
        guard let poolImplementation = payload.implementations.additionalProperties[kind.rawValue] else {
          return nil
        }
        
        return .init(
          type: kind,
          name: poolImplementation.name,
          description: poolImplementation.description,
          urlString: poolImplementation.url,
          socials: poolImplementation.socials
        )
      }
    
    return payload.pools.compactMap { pool -> StakingPool? in
      do {
        guard 
          let poolType = StakingPool.Implementation.Kind(rawValue: pool.implementation.rawValue),
          let poolImplementation = poolTypes.first(where: { $0.type == poolType })
        else {
          return nil
        }
        
        let address = try Address.parse(pool.address)
        
        var jettonMaster: Address?
        if let jettonMasterAddress = pool.liquid_jetton_master {
          jettonMaster = try? Address.parse(jettonMasterAddress)
        }
        
        return .init(
          address: address,
          name: pool.name,
          apy: Decimal(pool.apy),
          minStake: pool.min_stake,
          cycleEnd: pool.cycle_end,
          cycleStart: pool.cycle_start,
          jettonMaster: jettonMaster,
          implementation: poolImplementation
        )
      } catch {
        return nil
      }
    }
  }
}
