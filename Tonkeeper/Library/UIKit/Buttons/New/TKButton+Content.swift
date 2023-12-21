import UIKit

enum TKNewButton {
  static func titleButton(buttonCategory: TKButtonCategory,
                          buttonSize: TKButtonSize) -> TKButtonControl<ButtonTitleContentView> {
    let content = ButtonTitleContentView()
    return TKButtonControl(buttonContent: content, buttonCategory: buttonCategory, buttonSize: buttonSize)
  }
}

extension TKButtonControl where ButtonContent == ButtonTitleContentView {
  var title: String {
    get {
      buttonContent.label.text ?? ""
    }
    set {
      buttonContent.label.text = newValue
    }
  }
}
