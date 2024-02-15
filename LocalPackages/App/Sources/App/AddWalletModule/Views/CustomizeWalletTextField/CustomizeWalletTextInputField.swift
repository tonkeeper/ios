import UIKit
import TKUIKit
import TKCore

public extension TKTextInputField where InputControl == CustomizeWalletInputControl {
  var emoji: String {
    get {
      inputControl.emoji
    }
    set {
      inputControl.emoji = newValue
    }
  }
  
  var walletTintColor: UIColor? {
    get {
      inputControl.walletTintColor
    }
    set {
      inputControl.walletTintColor = newValue
    }
  }
  
  var placeholder: String {
    get {
      inputControl.placeholder
    }
    
    set {
      inputControl.placeholder = newValue
    }
  }
}

public final class CustomizeWalletTextInputField: TKTextInputField<CustomizeWalletInputControl> {
  init() {
    super.init(
      inputControl: CustomizeWalletInputControl(
        inputControl: TKTextInputFieldPlaceholderInputControl(
          inputControl: TKTextInputFieldTextFieldInputControl()
        )
      )
    )
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
