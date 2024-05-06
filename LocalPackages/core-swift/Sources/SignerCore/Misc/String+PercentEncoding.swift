import Foundation

extension String {
  var percentEncoded: String? {
    return self
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
      .replacingOccurrences(of: "+", with: "%2B")
  }
}
