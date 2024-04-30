import Foundation

public actor WatchOnlyWalletAddressInputController {
  public enum State {
    case none
    case resolving
    case resolved(ResolvableAddress)
    case failed
  }
  
  public var didUpdateState: ((State) -> Void)?
  private var state: State = .none {
    didSet {
      didUpdateState?(state)
    }
  }
  
  private var task: Task<(), Never>?
  
  private let addressResolver: AddressResolver
  
  init(addressResolver: AddressResolver) {
    self.addressResolver = addressResolver
  }
  
  public func start(didUpdateState: @escaping @Sendable (State) -> Void) {
    self.didUpdateState = didUpdateState
    state = .none
  }
  
  public func resolveAddress(input: String) async {
    self.task?.cancel()
    guard !input.isEmpty else {
      self.state = .none
      return
    }
    self.task = Task {
      self.state = .none
      try? await Task.sleep(nanoseconds: 750_000_000)
      guard !Task.isCancelled else { return }
      
      self.state = .resolving
      do {
        let resolvableAddress = try await self.addressResolver.resolveRecipient(input: input)
        self.state = .resolved(resolvableAddress)
      } catch {
        self.state = .failed
      }
    }
  }
}
