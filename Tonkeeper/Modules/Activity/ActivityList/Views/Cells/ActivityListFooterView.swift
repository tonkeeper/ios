//
//  ActivityListFooterView.swift
//  Tonkeeper
//
//  Created by Grigory on 11.8.23..
//

import UIKit

final class ActivityListFooterView: UICollectionReusableView, Reusable {
  enum State {
    case none
    case loading
    case error(title: String?)
  }
  
  var state: State = .none {
    didSet {
      didChangeState()
    }
  }
  
  var didTapRetryButton: (() -> Void)?
  
  private let loaderView = LoaderView(size: .small)
  private let retryButton = TKButton(configuration: .tertiarySmall)
    
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    loaderView.frame = bounds
    retryButton.sizeToFit()
    retryButton.center = CGPoint(x: bounds.width/2, y: bounds.height/2)
  }
}

private extension ActivityListFooterView {
  func setup() {
    addSubview(loaderView)
    addSubview(retryButton)
    
    retryButton.addAction(.init(handler: { [weak self] in self?.didTapRetryButton?() }), for: .touchUpInside)
    
    didChangeState()
  }
  
  func didChangeState() {
    switch state {
    case .none:
      loaderView.stopAnimation()
      loaderView.isHidden = true
      retryButton.isHidden = true
      retryButton.title = nil
    case .loading:
      loaderView.startAnimation()
      loaderView.isHidden = false
      retryButton.isHidden = true
      retryButton.title = nil
    case .error(let title):
      loaderView.stopAnimation()
      loaderView.isHidden = true
      retryButton.isHidden = false
      let buttonTitle: TKButton.Model.Title?
      if let title = title {
        buttonTitle = .string(title)
      } else {
        buttonTitle = nil
      }
      retryButton.configure(model: TKButton.Model(title: buttonTitle))
    }
    setNeedsLayout()
  }
}

