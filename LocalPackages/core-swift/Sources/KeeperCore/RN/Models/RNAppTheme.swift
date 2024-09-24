import Foundation
import TonSwift

public struct RNAppTheme: Codable {
  public struct State: Codable {
    public let selectedTheme: String
    
    public init(selectedTheme: String) {
      self.selectedTheme = selectedTheme
    }
  }
  
  public let state: State
  
  public init(state: State) {
    self.state = state
  }
}
