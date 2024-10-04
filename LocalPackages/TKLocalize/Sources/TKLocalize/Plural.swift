import Foundation

public enum Plural {
  case zero
  case one
  case few
  case many
  case other
}

public func plural(count: Int) -> Plural {
  let languageCode: String? = {
    if #available(iOS 16, *) {
      Locale.current.language.languageCode?.identifier
    } else {
      Locale.current.languageCode
    }
  }()
  switch languageCode {
  case "ru":
    return russianPlural(count: count)
  default:
    return defaultPlural(count: count)
  }
}

func defaultPlural(count: Int) -> Plural {
  switch count {
  case 1:
    return .one
  default:
    return .other
  }
}

func russianPlural(count: Int) -> Plural {
  if count == 0 {
    return .zero
  }
  if count % 10 == 1 && count % 100 != 11 {
    return .one
  }
  if let index = [2, 3, 4].firstIndex(of: count % 10), index >= 0 && [12, 13, 14].firstIndex(of: count % 100) == nil {
    return .few
  }
  if count % 10 == 0 {
    return .many
  }
  if let index = [5, 6, 7, 8, 9].firstIndex(of: count % 10), index >= 0 {
    return .many
  }
  if let index = [11, 12, 13, 14].firstIndex(of: count % 100), index >= 0 {
    return .many
  }
  return .other
}
