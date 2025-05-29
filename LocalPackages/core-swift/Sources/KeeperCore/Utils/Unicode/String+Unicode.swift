import Foundation

extension String {
  public func convertingUnicodeEscapes() -> String {
    guard let removedPercentEncoding = self.removingPercentEncoding else {
      return self
    }
    guard let regex = try? NSRegularExpression(pattern: "\\\\u([0-9a-fA-F]{4})") else {
      return self
    }
    
    let range = NSRange(removedPercentEncoding.startIndex..., in: removedPercentEncoding)
    var result = removedPercentEncoding
    let matches = regex.matches(in: removedPercentEncoding, range: range)
    
    for match in matches.reversed() {
      guard let hexRange = Range(match.range(at: 1), in: removedPercentEncoding),
            let matchRange = Range(match.range, in: removedPercentEncoding) else {
        continue
      }
      
      let hexString = String(removedPercentEncoding[hexRange])
      guard let unicodeValue = Int(hexString, radix: 16),
            let unicodeScalar = UnicodeScalar(unicodeValue) else {
        continue
      }
      
      let replacement = String(unicodeScalar)
      result.replaceSubrange(matchRange, with: replacement)
    }
    
    return result
  }
}
