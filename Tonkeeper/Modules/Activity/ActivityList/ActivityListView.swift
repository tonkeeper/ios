//
//  ActivityListActivityListView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

final class ActivityListView: UIView {
  
  let collectionView = UICollectionView(frame: .zero, collectionViewLayout: .init())
  private var headerView: UIView?

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    collectionView.frame = bounds
    layoutHeader()
  }
  
  private func layoutHeader() {
    guard let headerView = headerView else { return }
    let headerViewSize = headerView.systemLayoutSizeFitting(
      systemLayoutSizeFitting(.init(width: bounds.width, height: 0),
                              withHorizontalFittingPriority: .required, verticalFittingPriority: .defaultHigh)
    )
    headerView.frame = .init(
      origin: .init(x: 0, y: -headerViewSize.height),
      size: .init(width: bounds.width, height: headerViewSize.height)
    )
    collectionView.contentInset.top = headerViewSize.height
  }
  
  // MARK: - HeaderView
  
  func setHeaderView(_ headerView: UIView) {
    self.headerView = headerView
    self.collectionView.addSubview(headerView)
    setNeedsLayout()
  }
}

// MARK: - Private

private extension ActivityListView {
  func setup() {
    collectionView.backgroundColor = .Background.page
    addSubview(collectionView)
  }
}
