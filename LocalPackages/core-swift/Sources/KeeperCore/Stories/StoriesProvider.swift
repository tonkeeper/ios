import Foundation

public final class StoryProvider {
  public enum State {
    case none
    case loading
    case story(Story)
  }
  
  public var state: State {
    get {
      return lock.withLock {
        _state
      }
    }
    set {
      var observers = [UUID: () -> Void]()
      lock.withLock {
        observers = self.observers
        _state = newValue
      }
      observers.forEach { $0.value() }
    }
  }
  private var _state: State = .none
  private var loadTask: Task<(), Never>?
  private var observers = [UUID: () -> Void]()
  
  private let lock = NSLock()
  
  private let storiesService: StoriesService
  
  init(storiesService: StoriesService) {
    self.storiesService = storiesService
  }
  
  public func addUpdateObserver<T: AnyObject>(_ observer: T,
                                              closure: @escaping (T) -> Void) {
    let id = UUID()
    let observerClosure: () -> Void = { [weak self, weak observer] in
      guard let self else { return }
      guard let observer else {
        self.observers.removeValue(forKey: id)
        return
      }
      closure(observer)
    }
    lock.withLock {
      self.observers[id] = observerClosure
    }
  }
  
  public func loadStoryToShow() {
    lock.withLock {
      if loadTask != nil {
        return
      }
      _state = .loading
      let task = Task { [weak self] in
        guard let self else { return }
        let state: State
        do {
          if let story = try await storiesService.loadStoryToShow() {
            state = .story(story)
          } else {
            state = .none
          }
        } catch {
          state = .none
        }
        var observers = [UUID: () -> Void]()
        lock.withLock {
          observers = self.observers
          self._state = state
          self.loadTask = nil
        }
        observers.forEach { $0.value() }
      }
      self.loadTask = task
    }
  }
}
