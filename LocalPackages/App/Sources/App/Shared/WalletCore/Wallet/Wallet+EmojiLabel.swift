import KeeperCore

extension Wallet {
    var emojiLabel: String {
        if case let .emoji(emoji) = icon { "\(emoji) \(label)" } else { label }
    }
}
