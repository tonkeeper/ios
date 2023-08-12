//
//  ActivityListActivityListView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import UIKit

final class ActivityListView: UIView {
  
  let collectionView = NotDelayCollectionView(frame: .zero, collectionViewLayout: .init())
  private var headerView: UIView?
  private var footerView: UIView?
  
  private var contentSizeObserveToken: NSKeyValueObservation?

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
    collectionView.contentInset.top = .collectionTopSpacing
    layoutHeader()
    layoutFooter()
  }
  
  private func layoutHeader() {
    guard let headerView = headerView else { return }
    let headerViewSize = headerView.systemLayoutSizeFitting(
      systemLayoutSizeFitting(.init(width: bounds.width, height: 0),
                              withHorizontalFittingPriority: .required, verticalFittingPriority: .defaultHigh)
    )
    headerView.frame = .init(
      origin: .init(x: 0, y: -headerViewSize.height - .collectionTopSpacing),
      size: .init(width: bounds.width, height: headerViewSize.height)
    )
    collectionView.contentInset.top = headerViewSize.height + .collectionTopSpacing
    collectionView.refreshControl?.bounds.origin.y = headerViewSize.height
  }
  
  private func layoutFooter() {
    guard let footerView = footerView else {
      collectionView.contentInset.bottom = 0
      return
    }
    let headerViewSize = footerView.intrinsicContentSize
    collectionView.contentInset.bottom = headerViewSize.height
    footerView.frame = .init(
      origin: .init(x: 0, y: collectionView.contentSize.height),
      size: .init(width: bounds.width, height: headerViewSize.height)
    )
  }
  
  // MARK: - HeaderView
  
  func setHeaderView(_ headerView: UIView) {
    self.headerView = headerView
    self.collectionView.addSubview(headerView)
    setNeedsLayout()
  }
  
  func setFooterView(_ footerView: UIView?) {
    self.footerView?.removeFromSuperview()
    self.footerView = footerView
    if let footerView = footerView {
      self.collectionView.addSubview(footerView)
    }
    setNeedsLayout()
  }
}

// MARK: - Private

private extension ActivityListView {
  func setup() {
    collectionView.backgroundColor = .Background.page
    addSubview(collectionView)
    
    contentSizeObserveToken = collectionView
      .observe(\.contentSize, changeHandler: { [weak self] _, _ in
        guard let self else { return }
        self.layoutFooter()
      })
  }
}

private extension CGFloat {
  static let collectionTopSpacing: CGFloat = 14
}
