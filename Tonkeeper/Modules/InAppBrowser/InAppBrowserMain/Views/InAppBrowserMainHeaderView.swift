//
//  InAppBrowserMainHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

final class InAppBrowserMainHeaderView: UIView {
  
  var didTapLeftTwinButton: (() -> Void)?
  var didTapRightTwinButton: (() -> Void)?
  var didTapBackButton: (() -> Void)?
  
  private let contentView = UIView()
  let twinButton = TwinButton()
  let backButton: TKButton = {
    let button = TKButton(configuration: .init(type: .secondary,
                                               size: .xsmall,
                                               shape: .circle,
                                               contentInsets: .zero))
    return button
  }()
  let titleView = HeaderTwoLineTitleView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension InAppBrowserMainHeaderView {
  func setup() {
    backgroundColor = .Background.page
    
    backButton.isHidden = true
    
    addSubview(contentView)
    contentView.addSubview(titleView)
    contentView.addSubview(twinButton)
    contentView.addSubview(backButton)
    
    twinButton.leftButton.addAction(.init(handler: { [weak self] in
      self?.didTapLeftTwinButton?()
    }), for: .touchUpInside)
    
    twinButton.rightButton.addAction(.init(handler: { [weak self] in
      self?.didTapRightTwinButton?()
    }), for: .touchUpInside)
    
    backButton.addAction(.init(handler: { [weak self] in
      self?.didTapBackButton?()
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    
    contentView.translatesAutoresizingMaskIntoConstraints = false
    twinButton.translatesAutoresizingMaskIntoConstraints = false
    backButton.translatesAutoresizingMaskIntoConstraints = false
    titleView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      contentView.leftAnchor.constraint(equalTo: leftAnchor),
      contentView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      contentView.heightAnchor.constraint(equalToConstant: .contentViewHeight),
      
      titleView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor),
      titleView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
      titleView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 110),
      titleView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -110),
      titleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      
      twinButton.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -16),
      twinButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      
      backButton.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 16),
      backButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
    ])
  }
}

private extension CGFloat {
  static let contentViewHeight: CGFloat = 64
}


