//
//  PagingContentHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 30.5.23..
//

import UIKit

final class PagingContentHeaderView: UIControl, ConfigurableView {
  struct Model {
    let segmentControlModel: PageSegmentControl.Model?
  }
  
  var pageSegmentControl = PageSegmentControl()
  
  private var separatorTopViewConstraint: NSLayoutConstraint?
  private var separatorTopSegmentControlConstraint: NSLayoutConstraint?
  
  let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    view.isHidden = true
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: Model) {
    if let segmentControlModel = model.segmentControlModel {
      pageSegmentControl.configure(model: segmentControlModel)
      pageSegmentControl.isHidden = false
      separatorTopViewConstraint?.isActive = false
      separatorTopSegmentControlConstraint?.isActive = true
    } else {
      pageSegmentControl.configure(model: .init(items: []))
      pageSegmentControl.isHidden = true
      separatorTopSegmentControlConstraint?.isActive = false
      separatorTopViewConstraint?.isActive = true
    }
  }
}

private extension PagingContentHeaderView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(pageSegmentControl)
    addSubview(separatorView)
    
    pageSegmentControl.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    
    separatorTopViewConstraint = separatorView.topAnchor.constraint(equalTo: topAnchor, constant: 20)
    separatorTopSegmentControlConstraint = separatorView.topAnchor.constraint(equalTo: pageSegmentControl.bottomAnchor)
    
    NSLayoutConstraint.activate([
      pageSegmentControl.topAnchor.constraint(equalTo: topAnchor),
      pageSegmentControl.leftAnchor.constraint(equalTo: leftAnchor),
      pageSegmentControl.rightAnchor.constraint(equalTo: rightAnchor),
      
      separatorView.leftAnchor.constraint(equalTo: leftAnchor),
      separatorView.rightAnchor.constraint(equalTo: rightAnchor),
      separatorView.bottomAnchor.constraint(equalTo: bottomAnchor)
        .withPriority(.defaultHigh),
      separatorView.heightAnchor.constraint(equalToConstant: .separaterHeight)
//        .withPriority(.defaultHigh)
    ])
  }
}

private extension CGFloat {
  static let separaterHeight: CGFloat = 0.5
}

