//
//  TransactionCellStatusView.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

extension TransactionCellContentView {
  
  final class TransactionCellStatusView: UIView, ConfigurableView, ContainerCollectionViewCellContent {
    
    let label = UILabel()
    
    struct Model {
      let status: NSAttributedString?
    }
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
      super.layoutSubviews()
      label.frame = bounds
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
      return label.sizeThatFits(size)
    }
    
    func configure(model: Model) {
      label.attributedText = model.status
      setNeedsLayout()
    }
    
    func prepareForReuse() {
      label.attributedText = nil
    }
  }
}

private extension TransactionCellContentView.TransactionCellStatusView {
  func setup() {
    addSubview(label)
  }
}
