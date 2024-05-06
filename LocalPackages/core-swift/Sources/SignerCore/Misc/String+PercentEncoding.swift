import Foundation

extension String {
  var percentEncoded: String? {
    let set = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    return (self as NSString).addingPercentEncoding(withAllowedCharacters: set)
  }
}
