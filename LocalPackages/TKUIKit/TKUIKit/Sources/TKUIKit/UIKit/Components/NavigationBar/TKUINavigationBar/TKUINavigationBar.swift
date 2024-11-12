import UIKit

public final class TKUINavigationBar: UIView {
  
  public enum Appearance {
    case `default`
    case transparent
  }
  
  public var apperance: Appearance = .default {
    didSet {
      setupAppearance()
    }
  }
  
  public var centerView: UIView? {
    didSet {
      oldValue?.removeFromSuperview()
      guard let centerView else { return }
      centerContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      centerContainer.addSubview(centerView)
      centerView.snp.makeConstraints { make in
        make.edges.equalTo(centerContainer)
      }
    }
  }
  
  public var leftViews = [UIView]() {
    didSet {
      oldValue.forEach { $0.removeFromSuperview() }
      guard !leftViews.isEmpty else { return }
      leftViews.forEach {
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        leftStackView.addArrangedSubview($0)
      }
    }
  }
  
  public var rightViews = [UIView]() {
    didSet {
      oldValue.forEach { $0.removeFromSuperview() }
      guard !rightViews.isEmpty else { return }
      rightViews.forEach {
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        rightStackView.addArrangedSubview($0)
      }
    }
  }
  
  public weak var scrollView: UIScrollView? {
    didSet {
      didSetScrollView()
    }
  }
  private var contentOffsetToken: NSKeyValueObservation?
  
  private let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  private let barView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  private let gradientView = TKGradientView(color: .Background.page, direction: .topToBottom)

  private let barContentContainer = UIView()
  
  private let centerContainer = UIView()
  
  private let leftStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.alignment = .center
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    return stackView
  }()
  
  private let rightStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.alignment = .center
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    return stackView
  }()
  
  private let separatorView: TKSeparatorView = {
    let view = TKSeparatorView()
    view.isHidden = true
    return view
  }()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(backgroundView)
    addSubview(gradientView)
    addSubview(barView)
    addSubview(separatorView)
    barView.addSubview(barContentContainer)
    barContentContainer.addSubview(leftStackView)
    barContentContainer.addSubview(centerContainer)
    barContentContainer.addSubview(rightStackView)
    
    setupConstraints()
    
    setupAppearance()
  }
  
  private func setupConstraints() {
    rightStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
    leftStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    barView.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide)
      make.left.bottom.right.equalTo(self).priority(.high)
      make.height.equalTo(CGFloat.barHeight)
    }
    
    barContentContainer.snp.makeConstraints { make in
      make.edges.equalTo(barView).inset(8)
    }
    
    leftStackView.snp.makeConstraints { make in
      make.left.top.bottom.equalTo(barContentContainer)
    }
    
    rightStackView.snp.makeConstraints { make in
      make.right.top.bottom.equalTo(barContentContainer)
    }
    
    centerContainer.snp.makeConstraints { make in
      make.top.bottom.equalTo(barContentContainer)
      make.left.greaterThanOrEqualTo(leftStackView.snp.right)
      make.right.lessThanOrEqualTo(rightStackView.snp.left)
      make.centerX.equalTo(barContentContainer)
    }
    
    separatorView.snp.makeConstraints { make in
      make.left.bottom.right.equalTo(self)
    }
    
    gradientView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
      make.bottom.equalTo(self)
    }
  }
  
  func didSetScrollView() {
    guard let scrollView else {
      contentOffsetToken?.invalidate()
      contentOffsetToken = nil
      return
    }
    contentOffsetToken = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
      let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
      self?.separatorView.isHidden = offset <= 0
    }
  }
  
  func setupAppearance() {
    switch apperance {
    case .default:
      backgroundView.backgroundColor = .Background.page
      barView.backgroundColor = .Background.page
      gradientView.isHidden = true
      separatorView.isHidden = false
    case .transparent:
      backgroundView.backgroundColor = .clear
      barView.backgroundColor = .clear
      gradientView.isHidden = false
      separatorView.isHidden = true
    }
  }
}

private extension CGFloat {
  static let barHeight: CGFloat = 64
  static let edgesPadding: CGFloat = 8
  static let contentPadding: CGFloat = 8
}
