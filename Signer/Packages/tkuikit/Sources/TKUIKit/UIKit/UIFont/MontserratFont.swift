import UIKit

public struct MontserratFont {
  public let name: String
  init(name: String) {
    self.name = name
    do {
      try registerFont(name: name)
    } catch {
      fatalError("Failed to register font: \(name)")
    }
  }
  
  public static let medium = MontserratFont(name: "Montserrat-Medium")
  public static let semibold = MontserratFont(name: "Montserrat-SemiBold")
  public static let bold = MontserratFont(name: "Montserrat-Bold")
}

enum FontError: Swift.Error {
   case failedToRegisterFont
}

func registerFont(name: String) throws {
  guard let fontUrl = Bundle.module.url(forResource: name, withExtension: "ttf"),
        let fontDataProvider = CGDataProvider(url: fontUrl as CFURL),
        let font = CGFont(fontDataProvider),
        CTFontManagerRegisterGraphicsFont(font, nil) else {
    throw FontError.failedToRegisterFont
  }
}
