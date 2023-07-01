//
//  PasscodeDotView.swift
//  Tonkeeper
//
//  Created by Grigory on 29.6.23..
//

import UIKit

final class PasscodeDotView: UIView {
  
  enum State {
    case empty
    case filled
    case success
    case failed
    
    var backgroundColor: UIColor {
      switch self {
      case .empty: return .Background.content
      case .filled: return .Accent.blue
      case .success: return .Accent.green
      case .failed: return .Accent.red
      }
    }
  }
  
  var state: State = .empty {
    didSet {
      updateStateAppearance()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override var intrinsicContentSize: CGSize {
    let side: CGFloat
    switch state {
    case .failed:
      side = .bigSide
    default:
      side = .side
    }
    return .init(width: side, height: side)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
  }
}

private extension PasscodeDotView {
  func setup() {
    updateStateAppearance()
  }
  
  func updateStateAppearance() {
    backgroundColor = state.backgroundColor
  }
}

private extension CGFloat {
  static let side: CGFloat = 12
  static let bigSide: CGFloat = 16
}
