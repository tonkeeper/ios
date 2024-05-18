//
//  StakeConfirmationView.swift
//
//
//  Created by Semyon on 17/05/2024.
//

import UIKit
import TKUIKit
import SnapKit

final class StakeConfirmationView: UIView {
  
  private let modalContentContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func embedContent(_ view: UIView) {
    modalContentContainer.addSubview(view)
    
    view.snp.makeConstraints { make in
      make.edges.equalTo(modalContentContainer)
    }
  }
}

private extension StakeConfirmationView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(modalContentContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    modalContentContainer.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide)
      make.left.bottom.right.equalTo(self).priority(.high)
    }
  }
}
