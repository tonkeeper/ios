import UIKit
import TKUIKit

public final class TKInputRecoveryPhraseViewController: GenericViewViewController<TKInputRecoveryPhraseView> {
  public var didUpdateText: ((String, Int) -> Void)? {
    get {
      customView.didUpdateText
    }
    set {
      customView.didUpdateText = newValue
    }
  }
  public var didBeginEditing: ((Int) -> Void)? {
    get {
      customView.didBeginEditing
    }
    set {
      customView.didBeginEditing = newValue
    }
  }
  public var didEndEditing: ((Int) -> Void)? {
    get {
      customView.didEndEditing
    }
    set {
      customView.didEndEditing = newValue
    }
  }
  public var shouldPaste: ((String, Int) -> Bool)? {
    get {
      customView.shouldPaste
    }
    set {
      customView.shouldPaste = newValue
    }
  }
  
  public var scrollViewContentInset: UIEdgeInsets {
    get {
      customView.scrollView.contentInset
    }
    set {
      customView.scrollView.contentInset = newValue
    }
  }
  
  public func configure(with model: TKInputRecoveryPhraseView.Model) {
    customView.configure(model: model)
  }
  
  public func setValidState(_ isValid: Bool, at index: Int) {
    guard customView.wordInputTextFields.count > index else { return }
    customView.wordInputTextFields[index].isValid = isValid
  }
  
  public func scrollToInput(at index: Int,
                            animationDuration: TimeInterval) {
    guard customView.wordInputTextFields.count > index else { return }
    let inputView = customView.wordInputTextFields[index]
    let convertedFrame = customView.scrollView.convert(inputView.frame, to: inputView.superview)
    let scrollViewMaxOrigin = customView.scrollView.contentSize.height
    - customView.scrollView.frame.height
    + customView.scrollView.contentInset.bottom
    let originY = min(
      convertedFrame.origin.y - customView.titleDescriptionView.frame.maxY - convertedFrame.size.height,
      scrollViewMaxOrigin
    )
    UIView.animate(withDuration: animationDuration) {
      self.customView.scrollView.contentOffset = .init(x: 0, y: originY)
    }
  }
  
  public func scrollToLastInput(animationDuration: TimeInterval) {
    guard !customView.wordInputTextFields.isEmpty else { return }
    scrollToInput(at: customView.wordInputTextFields.count - 1, animationDuration: animationDuration)
  }
  
  public func setContinueButtonModel(_ model: TKButtonControl<ButtonTitleContentView>.Model) {
    customView.continueButton.configure(model: model)
  }
  
  public func setWord(_ word: String, atIndex index: Int) {
    guard index <= customView.wordInputTextFields.count else { return }
    customView.wordInputTextFields[index].text = word
  }
  
  public func activateField(atIndex index: Int) {
    guard index < customView.wordInputTextFields.count else { return }
    customView.wordInputTextFields[index].becomeFirstResponder()
  }
}
