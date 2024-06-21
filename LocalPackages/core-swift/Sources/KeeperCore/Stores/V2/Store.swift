import Foundation

open class Store<Item: Equatable> {
  public typealias ObservationClosure = (Item) -> Void
  
  fileprivate var observations = [UUID: ObservationClosure]()
  fileprivate lazy var queue = DispatchQueue(label: "\(Self.self)Queue",
                                         attributes: .concurrent,
                                         target: .global(qos: .userInitiated))
  
  var item: Item {
    didSet {
      guard item != oldValue else { return }
      observations.forEach { $0.value(item) }
    }
  }
  
  init(item: Item) {
    self.item = item
    queue.async(flags: .barrier) {
      self.restoreInitialState()
    }
  }
  
  public func getItem() -> Item {
    queue.sync {
      return self.item
    }
  }
  
  public func getItem() async -> Item {
    await withCheckedContinuation { continuation in
      queue.async {
        continuation.resume(returning: self.item)
      }
    }
  }
  
  public func updateItemSync(_ block: @escaping (Item) -> Item) {
    queue.sync(flags: .barrier) {
      let updated = block(self.item)
      self.item = updated
    }
  }
  
  public func updateItem(_ block: @escaping (Item) -> Item) async {
    await withCheckedContinuation { continuation in
      queue.async(flags: .barrier) {
        let updated = block(self.item)
        guard self.item != updated else {
          continuation.resume()
          return
        }
        self.item = updated
        continuation.resume()
      }
    }
  }

  public func addObserver<T: AnyObject>(_ observer: T,
                                        sync: Bool = false,
                                        notifyOnAdded: Bool,
                                        closure: @escaping (T, Item) -> Void,
                                        observationTokenClosure: ((ObservationToken) -> Void)? = nil) {
    let operation = { [weak self] in
      guard let self else { return }
      let id = UUID()
      let handler: ObservationClosure = { [weak self, weak observer] item in
        guard let observer else {
          self?.removeObservation(key: id)
          return
        }
        closure(observer, item)
      }
      self.observations[id] = handler
      let observationToken = ObservationToken { [weak self] in
        self?.removeObservation(key: id)
      }
      observationTokenClosure?(observationToken)
      if notifyOnAdded {
        handler(item)
      }
    }
    sync
    ? queue.sync(flags: .barrier, execute: operation)
    : queue.async(flags: .barrier, execute: operation)
  }
  
  func updateItemHandler(newItem: Item, oldItem: Item) {}
  func restoreInitialState() {}
  
  private func removeObservation(key: UUID) {
    observations.removeValue(forKey: key)
  }
}
