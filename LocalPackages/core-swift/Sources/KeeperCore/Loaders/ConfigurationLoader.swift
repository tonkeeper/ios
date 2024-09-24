import Foundation

public actor ConfigurationLoader {
  
  private var loadTask: Task<Void, Never>?
  
  private let configurationStore: ConfigurationStore
  private let configurationService: RemoteConfigurationService
  
  init(configurationStore: ConfigurationStore,
       configurationService: RemoteConfigurationService) {
    self.configurationStore = configurationStore
    self.configurationService = configurationService
  }
  
  public func load() async {
    if let loadTask = loadTask {
      return await loadTask.value
    }
    loadTask = Task {
      let state = await configurationStore.getState()
      guard state.loadingTask == nil else { return }
      let task: Task<RemoteConfiguration, Never> = Task {
        do {
          let loadedConfiguration = try await configurationService.loadConfiguration()
          await configurationStore.setConfiguration(loadedConfiguration)
          await configurationStore.setLoadingTask(nil)
          return loadedConfiguration
        } catch {
          await configurationStore.setLoadingTask(nil)
          return (try? configurationService.getConfiguration()) ?? .empty
        }
      }
      await configurationStore.setLoadingTask(task)
    }
    await loadTask?.value
  }
}
