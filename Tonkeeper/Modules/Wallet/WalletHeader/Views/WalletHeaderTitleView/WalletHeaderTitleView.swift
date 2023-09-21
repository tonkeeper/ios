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
  
  var title: String? {
    didSet {
      titleLabel.attributedText = title?.attributed(with: .h3, alignment: .center, color: .Text.primary)
      bigTitleLabel.text = title
    }
  }
  
  weak var scrollView: UIScrollView? {
    didSet {
      didSetScrollView()
    }
  }
  
  var size: Size = .compact {
    didSet {
      guard size != oldValue else { return }
      didUpdateSize()
    }
  }
  
  var rightButtons = [UIView]() {
    didSet {
      rightButtonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      rightButtons.forEach { rightButtonsStackView.addArrangedSubview($0) }
    }
  }

  private var scrollViewContentOffsetObserveToken: NSKeyValueObservation?

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    return label
  }()
  
  private let bigTitleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h1)
    label.textColor = .Text.primary
    label.isHidden = true
    return label
  }()
  
  let connectionStatusView = WalletHeaderConnectionStatusView()
  
  private let rightButtonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  private let safeAreaView = UIView()
  private let contentView = UIView()
  
  private var contentViewHeightConstraint: NSLayoutConstraint?
  
  init(size: Size) {
    self.size = size
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    let height = safeAreaInsets.top + size.height
    return .init(width: UIView.noIntrinsicMetric,
                 height: height)
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
    contentView.addSubview(titleLabel)
    contentView.addSubview(bigTitleLabel)
    contentView.addSubview(rightButtonsStackView)
    contentView.addSubview(connectionStatusView)
    
    setupConstraints()
    didUpdateSize()
  }
  
  func setupConstraints() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    bigTitleLabel.translatesAutoresizingMaskIntoConstraints = false
    rightButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
    safeAreaView.translatesAutoresizingMaskIntoConstraints = false
    connectionStatusView.translatesAutoresizingMaskIntoConstraints = false
    
    contentViewHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: .compactHeight)
    contentViewHeightConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      contentView.leftAnchor.constraint(equalTo: leftAnchor),
      contentView.rightAnchor.constraint(equalTo: rightAnchor),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      
      
      bigTitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -.bigTitleBottomSpace),
      bigTitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: ContentInsets.sideSpace),

      rightButtonsStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      rightButtonsStackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -.scanQRButtonRightSpace),
      
      connectionStatusView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
      connectionStatusView.centerXAnchor.constraint(equalTo: centerXAnchor),
      titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -.smallTitleBottomSpace),
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
    bigTitleLabel.alpha = 1 - progress * 2.5
    titleLabel.alpha = progress * 2

    let translationY = (.largeHeight - .compactHeight) * progress
    transform = CGAffineTransformMakeTranslation(0, -translationY)
  }
  
  func didUpdateSize() {
    invalidateIntrinsicContentSize()
    switch size {
    case .compact:
      bigTitleLabel.isHidden = true
    case .large:
      bigTitleLabel.isHidden = false
      if let scrollView = scrollView {
        handleScrollViewScroll(scrollView: scrollView)
      } else {
        updateTitle(with: 0)
      }
    }
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
