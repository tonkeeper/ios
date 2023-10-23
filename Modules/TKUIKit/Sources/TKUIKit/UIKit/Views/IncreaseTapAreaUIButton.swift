//
//  IncreaseTapAreaUIButton.swift
//  
//
//  Created by Grigory Serebryanyy on 23.10.2023.
//

import UIKit

open class IncreaseTapAreaUIButton: UIButton {
  open var tapAreaInsets: NSDirectionalEdgeInsets = .zero
  
  open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds
      .insetBy(dx: -(tapAreaInsets.leading + tapAreaInsets.trailing),
               dy: -(tapAreaInsets.top + tapAreaInsets.bottom))
      .contains(point)
  }
}
