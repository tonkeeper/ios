import Foundation

public final class KnownAccountsProvider {
  
  private var _knownAccounts = [KnownAccount]()
  
  private var loadTask: Task<[KnownAccount], Never>?
  
  private let lock = NSLock()
  
  private let knownAccountsService: KnownAccountsService
  
  init(knownAccountsService: KnownAccountsService) {
    self.knownAccountsService = knownAccountsService
  }
  
  public func load() {
    _ = loadKnownAccountsTask()
  }
  
  public func getKnownAccounts() async -> [KnownAccount] {
    let task = loadKnownAccountsTask()
    return await task.value
  }
  
  private func loadKnownAccountsTask() -> Task<[KnownAccount], Never> {
    let task = lock.withLock {
      if let loadTask {
        return loadTask
      }
      let task = Task<[KnownAccount], Never> {
        do {
          let knownAccounts = try await knownAccountsService.loadKnownAccounts()
          return knownAccounts
        } catch {
          lock.withLock {
            self.loadTask = nil
          }
          return (try? knownAccountsService.getKnownAccounts()) ?? []
        }
      }
      self.loadTask = task
      return task
    }
    return task
  }
}
