//
//  UIControlClosure.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit
import TKUIKitLegacy

extension UIControl.Event: Hashable {}

class UIControlClosure: IncreaseTapAreaUIControl {
  
  struct UIAction {
    let handler: () -> Void
  }
  
  private var actions = [UIControl.Event: [UIAction]]()
  
  func addAction(_ action: UIAction, for event: UIControl.Event) {
    var eventActions = actions[event] ?? []
    eventActions.append(action)
    actions[event] = eventActions
  }
  
  func removeActions() {
    actions = [:]
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension UIControlClosure {
  func setup() {
    addTarget(self, action: #selector(handleTouchUpInsideEvent), for: .touchUpInside)
  }
  
  @objc func handleTouchUpInsideEvent() {
    actions[.touchUpInside]?.forEach { $0.handler() }
  }
}
