import Foundation

public struct AssetList: Codable {
  public struct Result: Codable {
    public var assets: [Asset]
  }
  public var result: Result
}
