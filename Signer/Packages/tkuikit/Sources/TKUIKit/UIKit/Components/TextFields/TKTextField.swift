import UIKit

public enum TKTextField {
  public static func placeholderTextField() -> TKTextInputContainer<TKPlaceholderInputView> {
    let placeholderInputView = TKPlaceholderInputView(textInputView: TKTextFieldInputView())
    return TKTextInputContainer(textInputView: placeholderInputView)
  }

  public static func placeholderTextView() -> TKTextInputContainer<TKPlaceholderInputView> {
    let placeholderInputView = TKPlaceholderInputView(textInputView: TKTextViewInputView())
    return TKTextInputContainer(textInputView: placeholderInputView)
  }

  public static func mnemonicTextField() -> TKTextInputContainer<TKMnemonicInputView> {
    let mnemonicInputView = TKMnemonicInputView(textFieldInputView: TKTextFieldInputView())
    return TKTextInputContainer(textInputView: mnemonicInputView)
  }
  
  public static func passwordTextField() -> TKTextInputContainer<TKPasswordInputView> {
    let passwordInputView = TKPasswordInputView(textFieldInputView: TKTextFieldInputView())
    return TKTextInputContainer(textInputView: passwordInputView)
  }
}

public extension TKTextInputContainer where TextInputView == TKPlaceholderInputView {
  var placeholder: String {
    get {
      textInputView.placeholder
    }
    set {
      textInputView.placeholder = newValue
    }
  }
}

public extension TKTextInputContainer where TextInputView == TKMnemonicInputView {
  var indexNumber: Int {
    get {
      textInputView.indexNumber
    }
    set {
      textInputView.indexNumber = newValue
    }
  }
}
