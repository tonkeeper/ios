import UIKit

public extension TKKeyboardView {
  struct Configuration {
    public enum Biometry {
      case touchId
      case faceId
      
      var image: UIImage {
        switch self {
        case .touchId: return .TKUIKit.Icons.Size36.fingerprint
        case .faceId: return .TKUIKit.Icons.Size36.faceid
        }
      }
    }
    
    public enum KeyboardButton {
      case digit(digit: Int)
      case backspace
      case decimalSeparator
      case biometry(Biometry)
      case empty
    }
    
    public struct Row {
      public let buttons: [KeyboardButton]
    }
    
    public let rows: [Row]
    
    public static func passcodeConfiguration(biometry: Biometry?) -> Configuration {
      let leftBottomButton: KeyboardButton
      if let biometry = biometry {
        leftBottomButton = .biometry(biometry)
      } else {
        leftBottomButton = .empty
      }
      
      let configuration = Configuration(
        rows: [
          Row(buttons: [
            KeyboardButton.digit(digit: 1),
            KeyboardButton.digit(digit: 2),
            KeyboardButton.digit(digit: 3)
          ]),
          Row(buttons: [
            KeyboardButton.digit(digit: 4),
            KeyboardButton.digit(digit: 5),
            KeyboardButton.digit(digit: 6)
          ]),
          Row(buttons: [
            KeyboardButton.digit(digit: 7),
            KeyboardButton.digit(digit: 8),
            KeyboardButton.digit(digit: 9)
          ]),
          Row(buttons: [
            leftBottomButton,
            KeyboardButton.digit(digit: 0),
            KeyboardButton.backspace
          ]),
        ]
      )
      return configuration
    }
  }
}
