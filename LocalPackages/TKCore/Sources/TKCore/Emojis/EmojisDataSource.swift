import Foundation

public struct EmojisDataSource {
  public struct Version: Decodable, Comparable {
    public static func < (lhs: EmojisDataSource.Version, 
                          rhs: EmojisDataSource.Version) -> Bool {
      lhs.major < rhs.major || (lhs.major == rhs.major && lhs.minor < rhs.minor)
    }
    
    public let minor: Int
    public let major: Int
    init?(version: String) {
      let components = version.components(separatedBy: ".")
      guard components.count == 2 else { return nil }
      guard let first = components.first,
            let last = components.last,
            let major = Int(first),
            let minor = Int(last) else { return nil }
      self.major = major
      self.minor = minor
    }
  }
  
  public struct Emoji: Decodable {
    enum Error: Swift.Error {
      case incorrectVersionValue
    }
    public let emoji: String
    public let emojiVersion: Version
    
    enum CodingKeys: String, CodingKey {
      case emoji
      case emojiVersion = "emoji_version"
    }
    
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.emoji = try container.decode(String.self, forKey: .emoji)
      let versionString = try container.decode(String.self, forKey: .emojiVersion)
      guard let version = Version(version: versionString) else { throw Error.incorrectVersionValue}
      self.emojiVersion = version
    }
  }

  public struct EmojiGroup: Decodable {
    public let emojis: [Emoji]
  }
  
  public init() {}
  
  public func loadData() async -> [Emoji] {
    guard let url = Bundle.module.url(forResource: .fileName, withExtension: .fileExtension),
          let data = try? Data(contentsOf: url) else {
      return []
    }
    let decoder = JSONDecoder()
    do {
      let groups = try decoder.decode([EmojiGroup].self, from: data)
      let emojis = groups.reduce([]) { partialResult, group in
        partialResult + group.emojis
      }
      return emojis
    } catch {
      return []
    }
  }
}

private extension String {
  static let fileName = "emoji_list"
  static let fileExtension = "json"
}
