//
//  SpacingView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

final class SpacingView: UIView {
  
  enum Spacing {
    case none
    case constant(CGFloat)
  }
  
  var horizontalSpacing: Spacing {
    didSet { invalidateIntrinsicContentSize() }
  }
  var verticalSpacing: Spacing {
    didSet { invalidateIntrinsicContentSize() }
  }
  
  init(horizontalSpacing: Spacing,
       verticalSpacing: Spacing) {
    self.horizontalSpacing = horizontalSpacing
    self.verticalSpacing = verticalSpacing
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    let width: CGFloat
    switch horizontalSpacing {
    case .none:
      width = UIView.noIntrinsicMetric
    case let .constant(value):
      width = value
    }
    
    let height: CGFloat
    switch verticalSpacing {
    case .none:
      height = UIView.noIntrinsicMetric
    case let .constant(value):
      height = value
    }
    
    return .init(width: width, height: height)
  }
}

private extension SpacingView {
  func setup() {
    backgroundColor = .clear
  }
}
