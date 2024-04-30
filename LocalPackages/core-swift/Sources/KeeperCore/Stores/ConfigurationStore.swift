import Foundation

actor ConfigurationStore {
  enum State {
    case idle
    case isLoading(Task<RemoteConfiguration, Swift.Error>)
  }
  
  private let configurationService: RemoteConfigurationService
  
  private var state: State = .idle
  
  init(configurationService: RemoteConfigurationService) {
    self.configurationService = configurationService
  }
  
  func load() async throws -> RemoteConfiguration {
    switch state {
    case .idle:
      let task = loadConfigurationTask()
      state = .isLoading(task)
      do {
        let value = try await task.value
        state = .idle
        return value
      } catch {
        state = .idle
        throw error
      }
    case .isLoading(let task):
      let configuration = try await task.value
      return configuration
    }
  }
  
  func getConfiguration() async throws -> RemoteConfiguration {
    switch state {
    case .idle:
      return try configurationService.getConfiguration()
    case .isLoading(let task):
      let configuration = try await task.value
      return configuration
    }
  }
}

private extension ConfigurationStore {
  func loadConfigurationTask() -> Task<RemoteConfiguration, Swift.Error> {
    return Task {
      do {
        return try await configurationService.loadConfiguration()
      } catch {
        throw error
      }
    }
  }
}
