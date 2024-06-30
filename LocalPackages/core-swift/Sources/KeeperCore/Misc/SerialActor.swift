import Foundation

public actor SerialActor {
  private var previousTask: Task<Void, Never>?
  
  public init() {}
  
  public func addTask(block: @Sendable @escaping () async -> Void) {
    previousTask = Task { [previousTask] in
      let _ = await previousTask?.result
      return await block()
    }
  }
}

