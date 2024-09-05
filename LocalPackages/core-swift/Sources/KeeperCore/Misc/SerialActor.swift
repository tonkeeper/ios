import Foundation

public actor SerialActor<T> {
  private var previousTask: Task<T, Swift.Error>?
  
  public init() {}
  
  public func addTask(block: @Sendable @escaping () async throws -> T) {
    previousTask = Task { [previousTask] in
      let _ = await previousTask?.result
      return try await block()
    }
  }
}

