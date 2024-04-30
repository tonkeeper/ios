import Foundation

actor KnownAccountsStore {
  enum State {
    case idle
    case isLoading(Task<[KnownAccount], Swift.Error>)
  }
  
  private var state: State = .idle
  private var attemptNumber = 0
  
  private let knownAccountsService: KnownAccountsService
  
  init(knownAccountsService: KnownAccountsService) {
    self.knownAccountsService = knownAccountsService
  }
  
  func load() async throws -> [KnownAccount] {
    switch state {
    case .idle:
      let task = loadKnownAccountsTask()
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
      let knownAccounts = try await task.value
      return knownAccounts
    }
  }
  
  func getKnownAccounts() async throws -> [KnownAccount] {
    switch state {
    case .idle:
      return try knownAccountsService.getKnownAccounts()
    case .isLoading(let task):
      let knownAccounts = try await task.value
      return knownAccounts
    }
  }
}

private extension KnownAccountsStore {
  func loadKnownAccountsTask() -> Task<[KnownAccount], Swift.Error> {
    return Task {
      do {
        return try await knownAccountsService.loadKnownAccounts()
      } catch {
        attemptNumber += 1
        guard attemptNumber < .maxLoadAttempts else { throw error }
        return try await loadKnownAccountsTask().value
      }
    }
  }
}

private extension Int {
  static let maxLoadAttempts = 3
}
