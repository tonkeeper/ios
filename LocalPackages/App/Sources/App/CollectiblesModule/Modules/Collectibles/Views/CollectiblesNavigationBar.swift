import UIKit
import TKUIKit

final class CollectiblesNavigationBar: UIView {
  
  struct ButtonItem {
    public let model: TKUIHeaderIconButton.Model
    public let action: () -> Void
    
    public init(model: TKUIHeaderIconButton.Model, action: @escaping () -> Void) {
      self.model = model
      self.action = action
    }
  }
  
  public var rightButtonItems = [ButtonItem]() {
    didSet {
      rightButtonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      rightButtonItems.forEach {
        let button = TKUIHeaderIconButton()
        button.padding = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        button.configure(model: $0.model)
        button.addTapAction($0.action)
        rightButtonsStackView.addArrangedSubview(button)
      }
    }
  }
  
  public var title: String? {
    didSet {
      titleLabel.text = title
    }
  }
  
  public var isLoading = false {
    didSet {
      guard isLoading != oldValue else { return }
      let alpha: CGFloat = isLoading ? 1 : 0
      self.loaderView.alpha = alpha
      self.loaderView.isLoading = self.isLoading
    }
  }
  
  private let barView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.page
    return view
  }()
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.h3.font
    label.textAlignment = .center
    label.textColor = .Text.primary
    return label
  }()
  
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    view.isHidden = true
    return view
  }()
  
  private let loaderView = TKLoaderView(size: .xSmall, style: .secondary)
  
  private let rightButtonsStackView: UIStackView = {
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
  
  private func setup() {
    self.loaderView.alpha = 0
    self.loaderView.isLoading = false
    
    addSubview(barView)
    barView.addSubview(titleLabel)
    barView.addSubview(separatorView)
    barView.addSubview(loaderView)
    barView.addSubview(rightButtonsStackView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    barView.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.left.right.equalTo(self)
      make.bottom.equalTo(self)
      make.height.equalTo(64)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.left.equalTo(barView).offset(16)
      make.centerY.equalTo(barView)
    }
    
    separatorView.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.height.equalTo(Constants.separatorWidth)
      make.bottom.equalTo(barView)
    }
    
    loaderView.snp.makeConstraints { make in
      make.centerY.equalTo(titleLabel)
      make.left.equalTo(titleLabel.snp.right).offset(8)
    }
    
    rightButtonsStackView.snp.makeConstraints { make in
      make.left.greaterThanOrEqualTo(loaderView.snp.right).offset(8)
      make.right.equalTo(barView).offset(-8)
      make.centerY.equalTo(barView)
    }
  }
  
  func didSetScrollView() {
    if let scrollView = scrollView {
      contentOffsetToken = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        self?.separatorView.isHidden = offset <= 0
      }
    } else {
      contentOffsetToken = nil
    }
  }
}
