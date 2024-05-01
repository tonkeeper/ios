import UIKit

public enum TKButton {
  public static func titleButton(buttonCategory: TKButtonCategory,
                                 buttonSize: TKButtonSize) -> TKButtonControl<ButtonTitleContentView> {
    let content = ButtonTitleContentView()
    return TKButtonControl(buttonContent: content, buttonCategory: buttonCategory, buttonSize: buttonSize)
  }
  
  public static func titleHeaderButton() -> TKHeaderButton<TKHeaderButtonTitleContent> {
    return TKHeaderButton(buttonContent: TKHeaderButtonTitleContent())
  }
  
  public static func iconHeaderButton() -> TKHeaderButton<TKHeaderButtonIconContent> {
    return TKHeaderButton(buttonContent: TKHeaderButtonIconContent())
  }
  
  public static func flatIconTitleButton() -> TKFlatButtonControl<TKFlatButtonTitleIconContent> {
    return TKFlatButtonControl(buttonContent: TKFlatButtonTitleIconContent())
  }
}

public extension TKButtonControl where ButtonContent == ButtonTitleContentView {
  var title: String {
    get {
      buttonContent.label.text ?? ""
    }
    set {
      buttonContent.label.text = newValue
    }
  }
}
