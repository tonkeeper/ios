//
//  TextFieldContainer.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

final class TextFieldContainer: UIView {
  enum State {
    case inactive
    case active
  }
  
  enum ValidationState {
    case valid
    case invalid
  }
  
  var state: State = .inactive {
    didSet {
      updateAppearance()
    }
  }
  
  var validationState: ValidationState = .valid {
    didSet {
      updateAppearance()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TextFieldContainer {
  func setup() {
    layer.cornerRadius = .cornerRadius
    updateAppearance()
  }
  
  func updateAppearance() {
    switch validationState {
    case .valid:
      backgroundColor = .Field.background
      layer.borderColor = UIColor.Field.activeBorder.cgColor
    case .invalid:
      backgroundColor = .Field.errorBackground
      layer.borderColor = UIColor.Field.errorBorder.cgColor
    }
    
    switch state {
    case .active:
      layer.borderWidth = .borderWidth
    case .inactive:
      switch validationState {
      case .valid:
        layer.borderWidth = 0
      case .invalid:
        layer.borderWidth = .borderWidth
      }
    }
  }
}

private extension CGFloat {
  static let borderWidth: CGFloat = 1.5
  static let cornerRadius: CGFloat = 16
}
