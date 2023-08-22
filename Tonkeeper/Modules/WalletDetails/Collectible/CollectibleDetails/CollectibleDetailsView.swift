//
//  CollectibleDetailsCollectibleDetailsView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 21/08/2023.
//

import UIKit

final class CollectibleDetailsView: UIView {

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private

private extension CollectibleDetailsView {
  func setup() {
    backgroundColor = .Background.page
  }
}
