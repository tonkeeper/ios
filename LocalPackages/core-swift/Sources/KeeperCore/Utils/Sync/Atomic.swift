import Foundation

@propertyWrapper
public struct Atomic<Value> {
  
  private var value: Value
  private let lock = NSLock()
  
  public init(wrappedValue value: Value) {
    self.value = value
  }
  
  public var wrappedValue: Value {
    get { return load() }
    set { update(newValue: newValue) }
  }
  
  func load() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
  
  mutating func update(newValue: Value) {
    lock.lock()
    defer { lock.unlock() }
    value = newValue
  }
}
