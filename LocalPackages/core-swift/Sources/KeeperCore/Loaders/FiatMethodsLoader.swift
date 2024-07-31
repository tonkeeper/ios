import Foundation

actor FiatMethodsLoader {
  private var taskInProgress: Task<(), Never>?
  
  private let fiatMethodsStore: FiatMethodsStore
  private let buySellMethodsService: BuySellMethodsService
  private let locationService: LocationService
  
  init(fiatMethodsStore: FiatMethodsStore,
       buySellMethodsService: BuySellMethodsService,
       locationService: LocationService) {
    self.fiatMethodsStore = fiatMethodsStore
    self.buySellMethodsService = buySellMethodsService
    self.locationService = locationService
  }
  
  nonisolated
  func loadFiatMethods(isMarketRegionPickerAvailable: Bool) {
    Task {
      await load(isMarketRegionPickerAvailable: isMarketRegionPickerAvailable)
    }
  }
  
  private func load(isMarketRegionPickerAvailable: Bool) {
    if let taskInProgress {
      taskInProgress.cancel()
      self.taskInProgress = nil
    }
    
    let task = Task {
      await fiatMethodsStore.updateState { _ in
        FiatMethodsStore.StateUpdate(newState: .loading)
      }
      do {
        let methods: FiatMethods
        if isMarketRegionPickerAvailable {
          methods = try await loadDefault()
        } else {
          methods = try await loadByLocation()
        }
        guard !Task.isCancelled else { return }
        await fiatMethodsStore.updateState { _ in
          FiatMethodsStore.StateUpdate(newState: .fiatMethods(methods))
        }
      } catch {
        await fiatMethodsStore.updateState { _ in
          FiatMethodsStore.StateUpdate(newState: .none)
        }
      }
    }
    
    self.taskInProgress = task
  }

  private func loadDefault() async throws -> FiatMethods {
    try await buySellMethodsService.loadFiatMethods(countryCode: nil)
  }
  
  private func loadByLocation() async throws -> FiatMethods {
    let countryCode = try await locationService.getCountryCodeByIp()
    return try await buySellMethodsService.loadFiatMethods(countryCode: countryCode)
  }
}
