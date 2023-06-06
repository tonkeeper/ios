//
//  MultilineUIButton.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

class ResizableButton: UIButton {
  override var intrinsicContentSize: CGSize {
    let labelSize = titleLabel?.systemLayoutSizeFitting(.init(width: frame.width, height: .greatestFiniteMagnitude)) ?? .zero
    let buttonSize = CGSize(
      width: labelSize.width + titleEdgeInsets.left + titleEdgeInsets.right,
      height: labelSize.height + titleEdgeInsets.top + titleEdgeInsets.bottom
    )
    return buttonSize
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    titleLabel?.preferredMaxLayoutWidth = titleLabel?.frame.size.width ?? 0
  }
}
