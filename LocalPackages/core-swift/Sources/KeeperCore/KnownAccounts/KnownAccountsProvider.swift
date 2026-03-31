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

    private func loadKnownAccountsTask() -> Task<[KnownAccount], Never> {
        return lock.withLock {
            if let loadTask {
                return loadTask
            }
            let task = Task<[KnownAccount], Never> {
                do {
                    return try await knownAccountsService.loadKnownAccounts()
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
    }
}
