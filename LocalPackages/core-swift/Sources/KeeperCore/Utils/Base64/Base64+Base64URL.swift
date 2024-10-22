import Foundation

extension String {
  func base64UrlToBase64() -> String {
    guard (contains("-") || contains("_")) && !contains("=") else { return self }
    var result = self
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    if result.count % 4 != 0 {
      result.append(String(repeating: "=", count: 4 - result.count % 4))
    }
    return result
  }
  
  func base64ToBase64Url() -> String {
    self
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

extension String {
  func fixBase64() -> String {
    var result = self
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    if result.count % 4 != 0 {
      result.append(String(repeating: "=", count: 4 - result.count % 4))
    }
    return result
  }
}
