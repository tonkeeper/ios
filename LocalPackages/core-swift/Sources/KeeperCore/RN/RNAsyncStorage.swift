import Foundation
import CoreFoundation
import CryptoKit

public final class RNAsyncStorage {
  
  enum Error: Swift.Error {
    case failedToStringifyManifest
    case failedToSaveManifest
  }
  
  private let queue = DispatchQueue(label: "RNAsyncStorageQueue")
  private var didSetup = false
  private var manifest = [String: AnyObject]()
  
  public init() {}
  
  public func getValue<T: Codable>(key: String) async throws -> T? {
    guard let value = await getValue(key: key),
          let data = value.data(using: .utf8) else {
      return nil
    }
    let decoder = JSONDecoder()
    let decodedValue = try decoder.decode(T.self, from: data)
    return decodedValue
  }
  
  public func setValue<T: Codable>(value: T?, key: String) async throws {
    guard let value else {
      await setValue(value: nil, key: key)
      return
    }
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    await setValue(value: String(data: data, encoding: .utf8), key: key)
  }
  
  public func getValue(key: String) async -> String? {
    return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
      queue.async { [weak self] in
        guard let self else {
          continuation.resume(returning: nil)
          return
        }
        
        setup()
        
        let value = manifest[key]
        if let stringValue = value as? String {
          continuation.resume(returning: stringValue)
          return
        }
        if (value?.isEqual(kCFNull) == true) {
          guard let fileValue = getValueFromFile(key: key) else {
            manifest.removeValue(forKey: key)
            continuation.resume(returning: nil)
            return
          }
          continuation.resume(returning: fileValue)
          return
        }
        continuation.resume(returning: nil)
      }
    }
  }
  
  public func setValue(value: String?, key: String) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      queue.async { [weak self] in
        guard let self else {
          continuation.resume()
          return
        }
        
        setup()
        
        let filePath = getFilePath(key: key)
        if (value?.count ?? 0) <= .inlineValueThreshold {
          if manifest[key]?.isEqual(kCFNull) == true {
            try? FileManager.default.removeItem(atPath: filePath.path)
          }
          manifest[key] = value as AnyObject
          try? saveManifestToDisk()
          continuation.resume()
          return
        }
        
        try? value?.write(to: filePath, atomically: true, encoding: .utf8)
        if (manifest[key]?.isEqual(kCFNull) == false) {
          manifest[key] = kCFNull
          try? saveManifestToDisk()
        }
        continuation.resume()
      }
    }
  }
  
  private func getValueFromFile(key: String) -> String? {
    let path = getFilePath(key: key).path
    guard FileManager.default.fileExists(atPath: path) else {
      return nil
    }
    return try? String(contentsOfFile: path)
  }
  
  private func setup() {
    print("setup called")
    guard !didSetup else { return }
    print("setup performs")
    print(getStorageFolderPath())
    if !FileManager.default.fileExists(atPath: getStorageFolderPath().path) {
      try? createStorageDirectory()
    }
    loadManifest()
    didSetup = true
  }
  
  private func loadManifest() {
    let filePath = getManifestPath()
    guard FileManager.default.fileExists(atPath: filePath.path) else {
      return
    }
    
    do {
      let manifestData = try Data(contentsOf: filePath)
      let manifestJSON = try JSONSerialization.jsonObject(with: manifestData)
      guard let manifestDictionary = (manifestJSON as? [String: AnyObject]) else {
        return
      }
      self.manifest = manifestDictionary
    } catch {
      return
    }
  }
  
  private func saveManifestToDisk() throws {
    let stringified = try getStringifiedManifest()
    do {
      try stringified.write(toFile: getManifestPath().path, atomically: true, encoding: .utf8)
    } catch {
      throw Error.failedToSaveManifest
    }
  }
  
  private func getStringifiedManifest() throws -> String {
    let serialized = try JSONSerialization.data(withJSONObject: manifest, options: .fragmentsAllowed)
    let stringified = NSString(data: serialized, encoding: NSUTF8StringEncoding)
    guard let stringified else {
      throw Error.failedToStringifyManifest
    }
    return stringified as String
  }
  
  private func createStorageDirectory() throws {
    try FileManager.default.createDirectory(at: getStorageFolderPath(), withIntermediateDirectories: true)
  }
  
  private func getFilePath(key: String) -> URL {
    getStorageFolderPath().appendingPathComponent(getFileName(key: key))
  }
  
  private func getFileName(key: String) -> String {
    let digest = Insecure.MD5.hash(data: Data(key.utf8))
    return digest.map {
      String(format: "%02hhx", $0)
    }.joined()
  }
  
  private func getManifestPath() -> URL {
    getStorageFolderPath().appendingPathComponent(.manifest)
  }
  
  private func getStorageFolderPath() -> URL {
    FileManager.default
      .urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.bundleIdentifier ?? "")
      .appendingPathComponent(.storageFolder)
  }
}

private extension String {
  static let storageFolder = "RCTAsyncLocalStorage_V1"
  static let manifest = "manifest.json"
}

private extension Int {
  static let inlineValueThreshold = 1024
}
