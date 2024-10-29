import UIKit

public final class TKListContainerItemView: UIView, ConfigurableView {
  
  public struct Model: TKListContainerReconfigurableItem {
    public enum Value {
      case loading
      case value(TKListContainerItemValue)
    }
    
    public struct Icon {
      public let image: UIImage
      public let tintColor: UIColor
      public init(image: UIImage, tintColor: UIColor) {
        self.image = image
        self.tintColor = tintColor
      }
    }
    
    public var id: String?
    public let title: String
    public let titleIcon: Icon?
    public let value: Value
    public var action: TKListContainerItemAction?
    
    public func getView() -> UIView {
      let view = TKListContainerItemView()
      view.configure(model: self)
      return view
    }
    
    public func reconfigure(view: UIView) {
      (view as? TKListContainerItemView)?.configure(model: self)
    }
    
    public init(id: String? = nil,
                title: String,
                titleIcon: Icon? = nil,
                value: Value,
                action: TKListContainerItemAction?) {
      self.id = id
      self.title = title
      self.titleIcon = titleIcon
      self.value = value
      self.action = action
    }
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .body1,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    titleIconImageView.image = model.titleIcon?.image
    titleIconImageView.tintColor = model.titleIcon?.tintColor
    valueViewContainer.subviews.forEach { $0.removeFromSuperview() }
    switch model.value {
    case .loading:
      valueViewContainer.isHidden = true
      shimmerView.isHidden = false
      shimmerView.startAnimation()
    case .value(let value):
      shimmerView.isHidden = true
      shimmerView.stopAnimation()
      valueViewContainer.isHidden = false
      let valueView = value.getView()
      valueViewContainer.addSubview(valueView)
      valueView.snp.makeConstraints { make in
        make.edges.equalTo(valueViewContainer)
      }
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .top
    stackView.distribution = .fill
    stackView.spacing = 4
    return stackView
  }()
  
  private let titleContainerView = UIView()

  private let titleLabel = UILabel()
  private let titleIconImageView = UIImageView()
  private let valueStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  private let valueViewContainer = UIView()
  private let shimmerView = TKShimmerView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(stackView)
    
    titleIconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    stackView.addArrangedSubview(titleContainerView)
    titleContainerView.addSubview(titleLabel)
    titleContainerView.addSubview(titleIconImageView)
    
    stackView.addArrangedSubview(valueStackView)
    valueStackView.addArrangedSubview(valueViewContainer)
    valueStackView.addArrangedSubview(shimmerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    valueStackView.setContentHuggingPriority(.required, for: .horizontal)
    valueViewContainer.setContentHuggingPriority(.required, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }
    
    shimmerView.snp.makeConstraints { make in
      make.width.equalTo(80).priority(.medium)
      make.height.equalTo(24).priority(.medium)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.top.left.bottom.equalTo(titleContainerView)
    }
    
    titleIconImageView.snp.makeConstraints { make in
      make.right.lessThanOrEqualTo(titleContainerView)
      make.left.equalTo(titleLabel.snp.right).offset(4)
      make.centerY.equalTo(titleContainerView)
    }
  }
}
