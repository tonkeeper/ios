//
//  QRScannerSwipeDownButton.swift
//  Tonkeeper
//
//  Created by Grigory on 19.7.23..
//

import UIKit

final class QRScannerSwipeDownButton: UIButton {
  
  override var isHighlighted: Bool {
    didSet {
      highlightedBlurView.isHidden = !isHighlighted
      blurView.isHidden = isHighlighted
    }
  }
  
  private let blurView: UIVisualEffectView = {
    let blurEffect = UIBlurEffect(style: .regular)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.isUserInteractionEnabled = false
    blurView.alpha = 0.7
    blurView.layer.masksToBounds = true
    return blurView
  }()
  
  private let highlightedBlurView: UIVisualEffectView = {
    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.isUserInteractionEnabled = false
    blurView.alpha = 0.7
    blurView.layer.masksToBounds = true
    return blurView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let frame = CGRect(x: 0,
                       y: bounds.height/2 - .visibleSide/2,
                       width: .visibleSide, height: .visibleSide)
    blurView.frame = frame
    highlightedBlurView.frame = frame
    blurView.layer.cornerRadius = frame.width/2
    highlightedBlurView.layer.cornerRadius = frame.width/2
  }
  
  override var intrinsicContentSize: CGSize {
    .init(width: .side, height: .side)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return intrinsicContentSize
  }
}

private extension QRScannerSwipeDownButton {
  func setup() {
    layer.masksToBounds = true
    backgroundColor = .clear
    setImage(.Icons.Buttons.Header.swipe, for: .normal)
    tintColor = .Button.primaryForeground
    insertSubview(blurView, at: 0)
    insertSubview(highlightedBlurView, at: 0)
    highlightedBlurView.isHidden = true
    if let imageView = imageView {
      bringSubviewToFront(imageView)
    }
    contentEdgeInsets.left = -22
  }
}

private extension CGFloat {
  static let visibleSide: CGFloat = 32
  static let side: CGFloat = 54
}
