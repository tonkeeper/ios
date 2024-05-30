import Foundation
import TonSwift

actor StonfiAssetsStore {
  typealias ObservationClosure = (Event) -> Void
  
  enum Event {
    case didUpdateAssets(_ assets: StonfiAssets)
  }
  
  private let service: StonfiAssetsService
  private let repository: StonfiAssetsRepository
  
  init(service: StonfiAssetsService, repository: StonfiAssetsRepository) {
    self.service = service
    self.repository = repository
  }
  
  func getAssets() async -> StonfiAssets {
    let storedAssets = (try? repository.getAssets()) ?? StonfiAssets()
    guard !storedAssets.isValid else { return storedAssets }
    
    do {
      return try await service.loadAssets(loadCommunity: false)
    } catch {
      return storedAssets
    }
  }
  
  func loadAssetsInfo(addresses: [Address]) async -> [StonfiAsset] {
    do {
      return try await service.loadAssetsInfo(addresses: addresses)
    } catch {
      return []
    }
  }
  
  func setAssets(_ assets: StonfiAssets) {
    try? repository.saveAssets(assets)
    observations.values.forEach { $0(.didUpdateAssets(assets)) }
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
