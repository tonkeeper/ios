import Foundation
import TonSwift

actor HistoryListPaginator {
  enum State {
    case idle
    case isLoading
  }
  
  var eventHandler: ((PaginationEvent<HistoryListSection>) -> Void)?
  func setEventHandler(_ eventHandler: ((PaginationEvent<HistoryListSection>) -> Void)?) { self.eventHandler = eventHandler }
  
  private let limit = 25
  private var nextFrom: Int64?
  private var state: State = .idle
  
  private var sections = [HistoryListSection]()
  private var sectionsMap = [Date: Int]()
  
  private let wallet: Wallet
  private let loader: HistoryListLoader
  private let nftService: NFTService
  private let accountEventMapper: AccountEventMapper
  private let dateFormatter: DateFormatter
  
  // MARK: - Init
  
  init(wallet: Wallet,
       loader: HistoryListLoader,
       nftService: NFTService,
       accountEventMapper: AccountEventMapper,
       dateFormatter: DateFormatter) {
    self.wallet = wallet
    self.loader = loader
    self.nftService = nftService
    self.accountEventMapper = accountEventMapper
    self.dateFormatter = dateFormatter
  }
  
  // MARK: - Logic
  
  func start() async {
    state = .isLoading
    nextFrom = nil
    if let cachedEvents = try? loader.cachedEvents(wallet: wallet), !cachedEvents.events.isEmpty {
      await handleCachedEvents(cachedEvents)
      eventHandler?(.cached(sections))
    } else {
      eventHandler?(.loading)
    }
    
    do {
      let events = try await loadNextPage()
      sections = []
      sectionsMap = [:]
      if events.events.isEmpty {
        eventHandler?(.empty)
      } else {
        await handleLoadedEvents(events)
        eventHandler?(.loaded(sections))
      }
    } catch {
      eventHandler?(.empty)
    }
    state = .idle
    await loadNext()
  }
  
  func reload() async {
    state = .isLoading
    nextFrom = nil
    do {
      let events = try await loadNextPage()
      sections = []
      sectionsMap = [:]
      if events.events.isEmpty {
        eventHandler?(.empty)
      } else {
        await handleLoadedEvents(events)
        eventHandler?(.loaded(sections))
      }
    } catch {
      eventHandler?(.empty)
    }
    state = .idle
    await loadNext()
  }
  
  func loadNext() async {
    switch state {
    case .idle:
      guard nextFrom != 0 else { return }
      state = .isLoading
      eventHandler?(.pageLoading)
      do {
        let events = try await loadNextPage()
        await handleLoadedEvents(events)
        eventHandler?(.nextPage(sections))
      } catch {
        eventHandler?(.pageLoadingFailed)
      }
      state = .idle
    case .isLoading:
      return
    }
  }
}

private extension HistoryListPaginator {
  func handleLoadedEvents(_ events: AccountEvents) async {
    let nfts = await handleEventsWithNFTs(events: events.events)
    handleEvents(events, nfts: nfts)
  }
  
  func handleCachedEvents(_ events: AccountEvents) async {
    let nfts = await handleCachedEventsWithNFTs(events: events.events)
    handleEvents(events, nfts: nfts)
  }
  
  func handleEvents(_ events: AccountEvents, nfts: NFTsCollection) {
//    let calendar = Calendar.current
//    var updatedSections = [HistoryListSection]()
//    for event in events.events {
//      let eventDate = Date(timeIntervalSince1970: event.timestamp)
//      let dateFormat: String
//      let dateComponents: DateComponents
//      if calendar.isDateInToday(eventDate)
//          || calendar.isDateInYesterday(eventDate)
//          || calendar.isDate(eventDate, equalTo: Date(), toGranularity: .month) {
//        dateComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
//        dateFormat = "HH:mm"
//      } else {
//        dateComponents = calendar.dateComponents([.year, .month], from: eventDate)
//        dateFormat = "MMM d 'at' HH:mm"
//      }
//
//      guard let sectionDate = calendar.date(from: dateComponents) else { continue }
//      
//      let eventModel = accountEventMapper.mapEvent(
//        event,
//        eventDate: eventDate,
//        nftsCollection: nfts,
//        accountEventRightTopDescriptionProvider: HistoryAccountEventRightTopDescriptionProvider(
//          dateFormatter: dateFormatter,
//          dateFormat: dateFormat
//        ),
//        isTestnet: wallet.isTestnet
//      )
//      
//      if let sectionIndex = sectionsMap[sectionDate],
//         sections.count > sectionIndex {
//        let section = sections[sectionIndex]
//        let updatedEvents = section.events + CollectionOfOne(eventModel)
//          .sorted(by: { $0.date > $1.date })
//        let updatedSection = HistoryListSection(
//          date: section.date,
//          title: section.title,
//          events: updatedEvents
//        )
//        if let index = updatedSections.firstIndex(where: { $0.date == updatedSection.date }) {
//          updatedSections.remove(at: index)
//          updatedSections.insert(updatedSection, at: index)
//        } else {
//          updatedSections.append(updatedSection)
//        }
//        sections.remove(at: sectionIndex)
//        sections.insert(updatedSection, at: sectionIndex)
//      } else {
//        let section = HistoryListSection(
//          date: sectionDate,
//          title: accountEventMapper.mapEventsSectionDate(sectionDate),
//          events: [eventModel]
//        )
//        updatedSections.append(section)
//        sections = sections + CollectionOfOne(section)
//          .sorted(by: { $0.date > $1.date })
//        sectionsMap = Dictionary(uniqueKeysWithValues: sections.enumerated().map { ($0.element.date, $0.offset) })
//      }
//    }
  }
  
  func loadNextPage() async throws -> AccountEvents {
    let events = try await loader.loadEvents(
      wallet: wallet,
      beforeLt: nextFrom,
      limit: limit
    )
    self.nextFrom = events.nextFrom
    if events.events.isEmpty && events.nextFrom != 0 {
      return try await loadNextPage()
    }
    return events
  }
  
  func handleEventsWithNFTs(events: [AccountEvent]) async -> NFTsCollection {
    let actions = events.flatMap { $0.actions }
    var nftAddressesToLoad = Set<Address>()
    var nfts = [Address: NFT]()
    for action in actions {
      switch action.type {
      case .nftItemTransfer(let nftItemTransfer):
        nftAddressesToLoad.insert(nftItemTransfer.nftAddress)
      case .nftPurchase(let nftPurchase):
        nfts[nftPurchase.nft.address] = nftPurchase.nft
        try? nftService.saveNFT(nft: nftPurchase.nft, isTestnet: wallet.isTestnet)
      default: continue
      }
    }
    guard !nftAddressesToLoad.isEmpty else { return NFTsCollection(nfts: nfts) }
    
    if let loadedNFTs = try? await nftService.loadNFTs(addresses: Array(nftAddressesToLoad), isTestnet: wallet.isTestnet) {
      nfts = loadedNFTs
    }
    
    return NFTsCollection(nfts: nfts)
  }
  
  func handleCachedEventsWithNFTs(events: [AccountEvent]) async ->  NFTsCollection {
    let actions = events.flatMap { $0.actions }
    var nfts = [Address: NFT]()
    for action in actions {
      switch action.type {
      case .nftItemTransfer(let nftItemTransfer):
        nfts[nftItemTransfer.nftAddress] = try? nftService.getNFT(
          address: nftItemTransfer.nftAddress,
          isTestnet: wallet.isTestnet
        )
      case .nftPurchase(let nftPurchase):
        nfts[nftPurchase.nft.address] = nftPurchase.nft
        try? nftService.saveNFT(
          nft: nftPurchase.nft,
          isTestnet: wallet.isTestnet
        )
      default: continue
      }
    }
    
    return NFTsCollection(nfts: nfts)
  }
}
