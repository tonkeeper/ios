import Foundation

public actor SerialActor<T> {
  private var previousTask: Task<T, Never>?
  
  public init() {}
  
  public func addTask(block: @Sendable @escaping () async -> T) {
    previousTask = Task { [previousTask] in
      let _ = await previousTask?.result
      return await block()
    }
  }
}

