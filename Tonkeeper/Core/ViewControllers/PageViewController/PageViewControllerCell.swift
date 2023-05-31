//
//  PageViewControllerCell.swift
//  Tonkeeper
//
//  Created by Grigory on 29.5.23..
//

import UIKit

final class PageViewControllerCell: UICollectionViewCell, Reusable {
  
  private var pageView: UIView?
  
  func addPageView(_ pageView: UIView) {
    self.pageView?.removeFromSuperview()
    self.pageView = pageView
    contentView.addSubview(pageView)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    self.pageView?.removeFromSuperview()
    self.pageView = nil
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    pageView?.frame = contentView.bounds
  }
}
