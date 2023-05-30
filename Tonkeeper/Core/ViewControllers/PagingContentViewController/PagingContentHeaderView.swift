//
//  PagingContentHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 30.5.23..
//

import UIKit

final class PagingContentHeaderView: UIControl {
  
  var pageSegmentControl = PageSegmentControl()
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

private extension PagingContentHeaderView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(pageSegmentControl)
    addSubview(separatorView)
    
    pageSegmentControl.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    
    let separatorHeightConstraint = separatorView.heightAnchor.constraint(equalToConstant: .separaterHeight)
    separatorHeightConstraint.priority = .defaultHigh
    
    NSLayoutConstraint.activate([
      pageSegmentControl.topAnchor.constraint(equalTo: topAnchor),
      pageSegmentControl.leftAnchor.constraint(equalTo: leftAnchor),
      pageSegmentControl.bottomAnchor.constraint(equalTo: bottomAnchor),
      pageSegmentControl.rightAnchor.constraint(equalTo: rightAnchor),
      
      separatorView.topAnchor.constraint(equalTo: pageSegmentControl.bottomAnchor),
      separatorView.leftAnchor.constraint(equalTo: leftAnchor),
      separatorView.rightAnchor.constraint(equalTo: rightAnchor),
      separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
      separatorHeightConstraint
    ])
  }
}

private extension CGFloat {
  static let separaterHeight: CGFloat = 0.5
}

