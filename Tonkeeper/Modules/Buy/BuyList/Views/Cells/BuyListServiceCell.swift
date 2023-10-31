//
//  BuyListServiceCell.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

protocol BuyListServiceCellDelegate: AnyObject {
  func buyListServiceCellDidTap(_ cell: BuyListServiceCell)
}

final class BuyListServiceCell: ContainerCollectionViewCell<ServiceCellContentView>, Reusable {
  
  weak var delegate: BuyListServiceCellDelegate?
  
  weak var imageLoader: ImageLoader? {
    didSet {
      cellContentView.imageLoader = imageLoader
    }
  }
  
  var isInGroup = false {
    didSet {
      didUpdateIsInGroup()
    }
  }
  
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension BuyListServiceCell {
  func setup() {
    cellContentView.addAction(.init(handler: { [weak self] in
      guard let self = self else { return }
      self.delegate?.buyListServiceCellDidTap(self)
    }), for: .touchUpInside)
  }
  
  func didUpdateIsInGroup() {
    separatorView.isHidden = isLastCell || !isInGroup
  }
}
