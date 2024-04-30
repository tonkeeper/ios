import UIKit

public protocol KeyboardObserving: AnyObject {
  func keyboardWillShow(_ notification: Notification)
  func keyboardDidShow(_ notification: Notification)
  func keyboardWillHide(_ notification: Notification)
  func keyboardDidHide(_ notification: Notification)
  func keyboardWillChangeFrame(_ notification: Notification)
  func keyboardDidChangeFrame(_ notification: Notification)
  func registerForKeyboardEvents()
  func unregisterFromKeyboardEvents()
}

private var kObserveTokens = "kObserveTokens"

public extension KeyboardObserving where Self: UIViewController {
  
  private var observeTokens: [NSObjectProtocol]? {
    get {
      return objc_getAssociatedObject(self, &kObserveTokens) as? [NSObject]
    }
    set {
      objc_setAssociatedObject(self, &kObserveTokens, newValue, .OBJC_ASSOCIATION_RETAIN)
    }
  }
  
  func keyboardWillShow(_ notification: Notification) {}
  func keyboardDidShow(_ notification: Notification) {}
  func keyboardWillHide(_ notification: Notification) {}
  func keyboardDidHide(_ notification: Notification) {}
  func keyboardWillChangeFrame(_ notification: Notification) {}
  func keyboardDidChangeFrame(_ notification: Notification) {}
  
  func registerForKeyboardEvents() {
    
    weak var weakSelf = self
    
    let tokens = [
      NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                             object: nil,
                                             queue: nil)
      { notification in
        weakSelf?.keyboardWillShow(notification)
      },
      
      NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification,
                                             object: nil,
                                             queue: nil)
      { notification in
        weakSelf?.keyboardDidShow(notification)
      },
      
      NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                             object: nil,
                                             queue: nil)
      { notification in
        weakSelf?.keyboardWillHide(notification)
      },
      
      NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidHideNotification,
                                             object: nil,
                                             queue: nil)
      { notification in
        weakSelf?.keyboardDidHide(notification)
      },
      
      NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification,
                                             object: nil,
                                             queue: nil)
      { notification in
        weakSelf?.keyboardWillChangeFrame(notification)
      },
      
      NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidChangeFrameNotification,
                                             object: nil,
                                             queue: nil)
      { notification in
        weakSelf?.keyboardDidChangeFrame(notification)
      }]
    
    self.observeTokens = tokens
    
  }
  
  func unregisterFromKeyboardEvents() {
    observeTokens?.forEach({ NotificationCenter.default.removeObserver($0) })
  }
}

public extension Notification {
  var keyboardSize: CGSize? {
    return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size
  }
  
  var keyboardAnimationDuration: Double? {
    return userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
  }
  
  var keyboardAnimationCurve: UIView.AnimationCurve? {
    guard let curveUInt = (userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?
      .intValue else {
      return nil
    }
    
    return UIView.AnimationCurve(rawValue: curveUInt)
  }
}
