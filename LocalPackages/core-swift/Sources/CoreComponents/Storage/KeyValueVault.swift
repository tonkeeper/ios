import Foundation

public protocol KeyValueVault {
  associatedtype StoreValue
  associatedtype StoreKey

  func saveValue(_ value: StoreValue, for key: StoreKey) throws
  func deleteValue(for key: StoreKey) throws
  func loadValue(key: StoreKey) throws -> StoreValue
}
