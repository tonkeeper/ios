import Foundation
import TonSwift

actor NftsStore {
  typealias ObservationClosure = (Event) -> Void
  enum Event {
    case nftsUpdate(nfts: [NFT], walletAddress: Address)
  }
  
  private let service: AccountNFTService
  
  init(service: AccountNFTService) {
    self.service = service
  }
  
  func getNfts(walletAddress: Address) -> [NFT] {
    return service.getAccountNfts(accountAddress: walletAddress)
  }
  
  func setNfts(_ nfts: [NFT], walletAddress: Address) {
    try? service.saveAccountNfts(accountAddress: walletAddress, nfts: nfts)
    observations.values.forEach { $0(.nftsUpdate(nfts: nfts, walletAddress: walletAddress)) }
  }
  
  private var observations = [UUID: ObservationClosure]()
  
  func addEventObserver<T: AnyObject>(_ observer: T,
                                      closure: @escaping (T, Event) -> Void) -> ObservationToken {
    let id = UUID()
    let eventHandler: (Event) -> Void = { [weak self, weak observer] event in
      guard let self else { return }
      guard let observer else {
        Task { await self.removeObservation(key: id) }
        return
      }
      
      closure(observer, event)
    }
    observations[id] = eventHandler
    
    return ObservationToken { [weak self] in
      guard let self else { return }
      Task { await self.removeObservation(key: id) }
    }
  }
  
  func removeObservation(key: UUID) {
    observations.removeValue(forKey: key)
  }
}
