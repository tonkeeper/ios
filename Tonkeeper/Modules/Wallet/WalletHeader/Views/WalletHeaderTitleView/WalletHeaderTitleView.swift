//
//  WalletHeaderTitleView.swift
//  Tonkeeper
//
//  Created by Grigory on 30.5.23..
//

import UIKit

final class WalletHeaderTitleView: UIView {

  enum Size {
    case compact
    case large
    
    var height: CGFloat {
      switch self {
      case .compact: return .compactHeight
      case .large: return .largeHeight
      }
    }
  }
  
  weak var scrollView: UIScrollView? {
    didSet {
      didSetScrollView()
    }
  }
  
  var rightButtons = [UIView]() {
    didSet {
      rightButtonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      rightButtons.forEach { rightButtonsStackView.addArrangedSubview($0) }
    }
  }

  private var scrollViewContentOffsetObserveToken: NSKeyValueObservation?

  let titleConnectionView = TitleConnectionView()
    
  private let rightButtonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  private let safeAreaView = UIView()
  private let contentView = UIView()
  
  private var contentViewHeightConstraint: NSLayoutConstraint?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    return .init(width: UIView.noIntrinsicMetric,
                 height: .compactHeight)
  }
  
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    if #available(iOS 16.0, *) {
      DispatchQueue.main.async {
        super.invalidateIntrinsicContentSize()
      }
    } else {
      super.invalidateIntrinsicContentSize()
    }
  }
}

private extension WalletHeaderTitleView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentView)
    contentView.addSubview(titleConnectionView)
    contentView.addSubview(rightButtonsStackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    titleConnectionView.translatesAutoresizingMaskIntoConstraints = false
    rightButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
    safeAreaView.translatesAutoresizingMaskIntoConstraints = false
    
    contentViewHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: .compactHeight)
    contentViewHeightConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      contentView.leftAnchor.constraint(equalTo: leftAnchor),
      contentView.rightAnchor.constraint(equalTo: rightAnchor),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      titleConnectionView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      titleConnectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
      titleConnectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

      rightButtonsStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      rightButtonsStackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -.scanQRButtonRightSpace),
    ])
  }
  
  func didSetScrollView() {
    scrollViewContentOffsetObserveToken = scrollView?
      .observe(\.contentOffset, changeHandler: { [weak self] scrollView, _ in
        guard let self = self else { return }
        self.handleScrollViewScroll(scrollView: scrollView)
      })
  }
  
  func handleScrollViewScroll(scrollView: UIScrollView) {
    let offsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    let tresholdPercentage = min(offsetY / .scrollTreshold, 1)
    self.updateTitle(with: tresholdPercentage)
  }
  
  func updateTitle(with progress: CGFloat) {
    titleConnectionView.alpha = 1 - progress * 2.5

    let translationY = (.largeHeight - .compactHeight) * progress
    transform = CGAffineTransformMakeTranslation(0, -translationY)
  }
}

private extension CGFloat {
  static let scanQRButtonRightSpace: CGFloat = 18
  static let largeHeight: CGFloat = 84
  static let compactHeight: CGFloat = 64
  static let scrollTreshold: CGFloat = 50
  static let smallTitleBottomSpace: CGFloat = 18
  static let bigTitleBottomSpace: CGFloat = 12
}
