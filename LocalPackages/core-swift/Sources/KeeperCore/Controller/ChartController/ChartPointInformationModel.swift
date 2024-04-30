import Foundation

public struct ChartPointInformationModel {
  public struct Diff {
    public enum Direction {
      case none
      case up
      case down
    }
    public let percent: String
    public let fiat: String
    public let direction: Direction
    
    public init(percent: String, fiat: String, direction: Direction) {
      self.percent = percent
      self.fiat = fiat
      self.direction = direction
    }
  }
  
  public let amount: String
  public let diff: Diff
  public let date: String
  
  public init(amount: String, diff: Diff, date: String) {
    self.amount = amount
    self.diff = diff
    self.date = date
  }
}
