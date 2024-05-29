import Foundation

public struct PairsList: Codable {
  public struct Result: Codable {
    public var pairs: [[String]]
  }
  public var result: Result
}
