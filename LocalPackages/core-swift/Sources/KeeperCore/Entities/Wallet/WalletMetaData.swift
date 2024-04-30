import Foundation

public struct WalletMetaData: Codable {
  public let label: String
  public let tintColor: WalletTintColor
  public let emoji: String
  
  public init(label: String,
              tintColor: WalletTintColor,
              emoji: String) {
    self.label = label
    self.tintColor = tintColor
    self.emoji = emoji
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.label = try container.decode(String.self, forKey: .label)
    self.emoji = try container.decode(String.self, forKey: .emoji)
    
    do {
      self.tintColor = try container.decode(WalletTintColor.self, forKey: .tintColor)
    } catch {
      self.tintColor = .defaultColor
    }
  }
}
