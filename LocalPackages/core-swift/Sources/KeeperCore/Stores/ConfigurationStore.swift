import Foundation

public final class ConfigurationStore: Store<ConfigurationStore.Event, ConfigurationStore.State> {
  public struct State {
    public let configuration: RemoteConfiguration
    public let loadingTask: Task<RemoteConfiguration, Never>?
  }
  
  public enum Event {
    case didUpdateConfiguration
  }
  
  private let repository: RemoteConfigurationRepository
  
  init(repository: RemoteConfigurationRepository) {
    self.repository = repository
    super.init(state: State(configuration: .empty, loadingTask: nil))
  }
  
  public override func createInitialState() -> State {
    do {
      return State(configuration: try repository.configuration, loadingTask: nil)
    } catch {
      return State(configuration: .empty, loadingTask: nil)
    }
  }
  
  public func getConfiguration() async -> RemoteConfiguration {
    let state = await getState()
    if let loadingTask = state.loadingTask {
      return await loadingTask.value
    } else {
      return state.configuration
    }
  }
  
  public func getConfiguration() -> RemoteConfiguration {
    let state = getState()
    return state.configuration
  }
  
  public func setConfiguration(_ configuration: RemoteConfiguration) async {
    await setState { state in
      let updatedState = State(configuration: configuration,
                               loadingTask: state.loadingTask)
      return StateUpdate(newState: updatedState)
    } notify: { [weak self] _ in
      self?.sendEvent(.didUpdateConfiguration)
    }
  }
  
  public func setLoadingTask(_ loadingTask: Task<RemoteConfiguration, Never>?) async {
    await setState { state in
      let updatedState = State(configuration: state.configuration,
                               loadingTask: loadingTask)
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      
    }
  }
}
