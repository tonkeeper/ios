import UIKit
import TKUIKit

final class NavigationBarView: UIView {
  
  var additionalInset: CGFloat {
    bounds.height - safeAreaInsets.top
  }
  
  private var isLarge = true
  
  let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  let barView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.h3.font
    label.textAlignment = .center
    label.textColor = .Text.primary
    return label
  }()
  
  let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    view.isHidden = true
    return view
  }()
  
  var title: String? {
    didSet {
      titleLabel.text = title
    }
  }

  let largeBarView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  var largeBarContentView: UIView? {
    didSet {
      didSetLargeBarContentView()
    }
  }
  
  weak var scrollView: UIScrollView? {
    didSet {
      didSetScrollView()
    }
  }
  
  private var contentOffsetToken: NSKeyValueObservation?
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setIsLarge(_ isLarge: Bool, animated: Bool) {
    self.isLarge = isLarge
    didChangeIsLarge(animated: animated)
  }
}

private extension NavigationBarView {
  func setup() {
    addSubview(largeBarView)
    addSubview(backgroundView)
    addSubview(barView)
    barView.addSubview(titleLabel)
    barView.addSubview(separatorView)
    
    setupConstraints()
    
    didChangeIsLarge(animated: false)
  }
  
  func setupConstraints() {
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    barView.translatesAutoresizingMaskIntoConstraints = false
    largeBarView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: topAnchor),
      backgroundView.leftAnchor.constraint(equalTo: leftAnchor),
      backgroundView.rightAnchor.constraint(equalTo: rightAnchor),
      
      barView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      barView.leftAnchor.constraint(equalTo: leftAnchor),
      barView.rightAnchor.constraint(equalTo: rightAnchor),
      barView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
      barView.heightAnchor.constraint(equalToConstant: 44),
      
      largeBarView.topAnchor.constraint(equalTo: barView.bottomAnchor),
      largeBarView.leftAnchor.constraint(equalTo: leftAnchor),
      largeBarView.rightAnchor.constraint(equalTo: rightAnchor),
      largeBarView.bottomAnchor.constraint(equalTo: bottomAnchor),
      largeBarView.heightAnchor.constraint(equalToConstant: .largeBarHeight),
      
      titleLabel.centerXAnchor.constraint(equalTo: barView.centerXAnchor),
      titleLabel.topAnchor.constraint(equalTo: barView.topAnchor, constant: 8.5),
      
      separatorView.leftAnchor.constraint(equalTo: leftAnchor),
      separatorView.rightAnchor.constraint(equalTo: rightAnchor),
      separatorView.heightAnchor.constraint(equalToConstant: 0.5),
      separatorView.bottomAnchor.constraint(equalTo: barView.bottomAnchor)
    ])
  }
  
  func didSetScrollView() {
    if let scrollView = scrollView {
      contentOffsetToken = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        self?.largeBarView.transform = CGAffineTransform(translationX: 0, y: -offset)
        let isLarge = offset <= .largeBarHeight - 20
        self?.setIsLarge(isLarge, animated: scrollView.isTracking)
        self?.separatorView.isHidden = offset < .largeBarHeight
      }
    } else {
      contentOffsetToken = nil
      largeBarView.transform = .identity
    }
  }
  
  func didChangeIsLarge(animated: Bool = false) {
    let duration: TimeInterval = animated ? 0.2 : 0
    let titleAlpha: CGFloat = isLarge ? 0 : 1
    let largeBarContentViewAlpha: CGFloat = isLarge ? 1 : 0
    
    UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
      self.titleLabel.alpha = titleAlpha
      self.largeBarContentView?.alpha = largeBarContentViewAlpha
    }
  }
  
  func didSetLargeBarContentView() {
    largeBarView.subviews.forEach { $0.removeFromSuperview() }
    guard let largeBarContentView = largeBarContentView else { return }
    largeBarView.addSubview(largeBarContentView)
    largeBarContentView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      largeBarContentView.leftAnchor.constraint(equalTo: largeBarView.leftAnchor, constant: 16),
      largeBarContentView.bottomAnchor.constraint(equalTo: largeBarView.bottomAnchor, constant: -12),
    ])
  }
}

private extension CGFloat {
  static let largeBarHeight: CGFloat = 52
}
