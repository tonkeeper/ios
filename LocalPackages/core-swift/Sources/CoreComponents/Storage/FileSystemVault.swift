import Foundation

public struct FileSystemVault<T: Codable, Key: CustomStringConvertible> {
  public enum LoadError: Swift.Error {
    case noItem(key: Key)
    case corruptedData(key: Key, error: DecodingError)
    case other(Swift.Error)
  }
  
  public enum SaveError: Swift.Error {
    case failedCreateFolder(url: URL)
    case corruptedData(key: Key, error: EncodingError)
    case other(key: Key, error: Swift.Error)
  }
  
  public enum DeleteError: Swift.Error {
    case noItem(key: Key)
    case failedDeleteItem(key: Key, error: Swift.Error)
  }
  
  private let fileManager: FileManager
  private let directory: URL
  
  private let decoder = JSONDecoder()
  
  public init(fileManager: FileManager,
              directory: URL) {
    self.fileManager = fileManager
    self.directory = directory
  }
  
  public func loadItem(key: Key) throws -> T {
    do {
      return try load(filename: key.description)
    } catch CocoaError.fileReadNoSuchFile {
      throw LoadError.noItem(key: key)
    } catch let decodingError as DecodingError {
      throw LoadError.corruptedData(key: key, error: decodingError)
    } catch {
      throw LoadError.other(error)
    }
  }
  
  public func loadAll() -> [T] {
    do {
      let content = try fileManager.contentsOfDirectory(atPath: folderPath.path)
      return content.compactMap { name -> T? in
        try? load(filename: name)
      }
    } catch {
      return []
    }
  }
  
  public func saveItem(_ item: T, key: Key) throws {
    do {
      try createFolderIfNeeded(url: folderPath)
    } catch {
      throw SaveError.failedCreateFolder(url: folderPath)
    }
    let url = folderPath.appendingPathComponent(key.description)
    do {
      let data = try JSONEncoder().encode(item)
      try data.write(to: url, options: .atomic)
    } catch let encodingError as EncodingError {
      throw SaveError.corruptedData(key: key, error: encodingError)
    } catch {
      throw SaveError.other(key: key, error: error)
    }
  }
  
  public func deleteItem(key: Key) throws {
    let url = folderPath.appendingPathComponent(key.description)
    guard fileManager.fileExists(atPath: url.path) else {
      throw DeleteError.noItem(key: key)
    }
    do {
      try fileManager.removeItem(at: url)
    } catch {
      throw DeleteError.failedDeleteItem(key: key, error: error)
    }
  }
}

private extension FileSystemVault {
  var folderPath: URL {
    let folderName = String(describing: T.self)
    let folderPath = directory.appendingPathComponent(
      folderName,
      isDirectory: true
    )
    return folderPath
  }
  
  func createFolderIfNeeded(url: URL) throws {
    let path = url.path
    guard !fileManager.fileExists(atPath: path) else { return }
    try fileManager.createDirectory(
      atPath: path,
      withIntermediateDirectories: true
    )
  }
  
  func load(filename: String) throws -> T {
    let url = folderPath.appendingPathComponent(filename)
    let data = try Data(contentsOf: url)
    let item = try decoder.decode(T.self, from: data)
    return item
  }
}
