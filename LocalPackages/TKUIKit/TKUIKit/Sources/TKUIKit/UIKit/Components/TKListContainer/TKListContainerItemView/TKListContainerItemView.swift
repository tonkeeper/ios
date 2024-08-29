import UIKit

public final class TKListContainerItemView: UIView, ConfigurableView {
  
  public struct Model: TKListContainerItem {
    public enum Value {
      case loading
      case value(TKListContainerItemValue)
    }
    
    public let title: String
    public let value: Value
    public let isHighlightable: Bool
    public let copyValue: String?
    
    public func getView() -> UIView {
      let view = TKListContainerItemView()
      view.configure(model: self)
      return view
    }
    
    public init(title: String,
                value: Value,
                isHighlightable: Bool,
                copyValue: String?) {
      self.title = title
      self.value = value
      self.isHighlightable = isHighlightable
      self.copyValue = copyValue
    }
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .body1,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
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
    return stackView
  }()
  
  private let titleStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 4
    stackView.alignment = .center
    return stackView
  }()
  private let titleLabel = UILabel()
  private let valueStackView: UIStackView = {
    let stackView = UIStackView()
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
    
    stackView.addArrangedSubview(titleStackView)
    titleStackView.addArrangedSubview(titleLabel)
    
    stackView.addArrangedSubview(valueStackView)
    valueStackView.addArrangedSubview(valueViewContainer)
    valueStackView.addArrangedSubview(shimmerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
    }
    
    shimmerView.snp.makeConstraints { make in
      make.width.equalTo(80)
      make.height.equalTo(24)
    }
  }
}
