import UIKit
// TODO: Refactor
public final class TKNavigationBar: UIView {
  
  public var configuration = Configuration(rightButtonItems: []) {
    didSet {
      didUpdateConfiguration()
    }
  }
  
  public var additionalInset: CGFloat {
    bounds.height - safeAreaInsets.top
  }
  
  public var title: String? {
    didSet {
      titleLabel.text = title
      largeTitleView.title = title
    }
  }
  
  public var isConnecting: Bool {
    get {
      largeTitleView.isLoading
    }
    set {
      largeTitleView.isLoading = newValue
    }
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

  let largeBarView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  let largeTitleView = LargeTitleView()
  
  private let rightButtonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 0
    return stackView
  }()
  
  private let largeBarRightButtonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 0
    return stackView
  }()

  public weak var scrollView: UIScrollView? {
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

private extension TKNavigationBar {
  func setup() {
    addSubview(largeBarView)
    addSubview(backgroundView)
    addSubview(barView)
    barView.addSubview(titleLabel)
    barView.addSubview(separatorView)
    
    barView.addSubview(rightButtonsStackView)
    largeBarView.addSubview(largeTitleView)
    largeBarView.addSubview(largeBarRightButtonsStackView)
    
    setupConstraints()
    
    didChangeIsLarge(animated: false)
  }
  
  func setupConstraints() {
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    barView.translatesAutoresizingMaskIntoConstraints = false
    largeBarView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    rightButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
    largeBarRightButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
    largeTitleView.translatesAutoresizingMaskIntoConstraints = false
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
      titleLabel.rightAnchor.constraint(equalTo: rightButtonsStackView.leftAnchor),
      
      separatorView.leftAnchor.constraint(equalTo: leftAnchor),
      separatorView.rightAnchor.constraint(equalTo: rightAnchor),
      separatorView.heightAnchor.constraint(equalToConstant: Constants.separatorWidth),
      separatorView.bottomAnchor.constraint(equalTo: barView.bottomAnchor),
      
      rightButtonsStackView.rightAnchor.constraint(equalTo: barView.rightAnchor, constant: -8),
      rightButtonsStackView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
      
      largeTitleView.leftAnchor.constraint(equalTo: largeBarView.leftAnchor, constant: 16),
      largeTitleView.bottomAnchor.constraint(equalTo: largeBarView.bottomAnchor, constant: -12),
      
      largeBarRightButtonsStackView.rightAnchor.constraint(equalTo: largeBarView.rightAnchor, constant: -8),
      largeBarRightButtonsStackView.centerYAnchor.constraint(equalTo: largeTitleView.centerYAnchor),
    ])
  }
  
  func didSetScrollView() {
    if let scrollView = scrollView {
      setIsLarge(true, animated: false)
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
      self.rightButtonsStackView.alpha = titleAlpha
      
      self.largeTitleView.alpha = largeBarContentViewAlpha
      self.largeBarRightButtonsStackView.alpha = largeBarContentViewAlpha
    }
  }
  
  func didUpdateConfiguration() {
    rightButtonsStackView.arrangedSubviews.forEach { rightButtonsStackView.removeArrangedSubview($0) }
    largeBarRightButtonsStackView.arrangedSubviews.forEach { largeBarRightButtonsStackView.removeArrangedSubview($0) }

    configuration.rightButtonItems.forEach {
      let button = TKUIHeaderIconButton()
      button.padding = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
      button.configure(model: $0.model)
      button.addTapAction($0.action)
      rightButtonsStackView.addArrangedSubview(button)
    }
    
    configuration.rightButtonItems.forEach {
      let button = TKUIHeaderIconButton()
      button.padding = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
      button.configure(model: $0.model)
      button.addTapAction($0.action)
      largeBarRightButtonsStackView.addArrangedSubview(button)
    }
  }
}

private extension CGFloat {
  static let largeBarHeight: CGFloat = 52
}
