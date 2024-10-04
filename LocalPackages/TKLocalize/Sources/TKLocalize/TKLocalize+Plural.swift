extension TKLocales.Settings.Purchases.Token {
  public static func tokenCount(count: Int) -> String {
    switch plural(count: count) {
    case .few: return TokenCount.few
    case .many: return TokenCount.many
    case .one: return TokenCount.one
    case .other: return TokenCount.other
    case .zero: return TokenCount.zero
    }
  }
}
