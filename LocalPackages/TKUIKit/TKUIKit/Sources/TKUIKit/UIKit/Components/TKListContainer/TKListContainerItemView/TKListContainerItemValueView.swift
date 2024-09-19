import UIKit

public protocol TKListContainerItemValue {
  func getView() -> UIView
}

public final class TKListContainerItemDefaultValueView: UIView, ConfigurableView {
  
  public struct Model: TKListContainerItemValue {
    public func getView() -> UIView {
      let view = TKListContainerItemDefaultValueView()
      view.configure(model: self)
      return view
    }
    
    public let topValue: String?
    public let bottomValue: String?
    
    public init(topValue: String? = nil, bottomValue: String? = nil) {
      self.topValue = topValue
      self.bottomValue = bottomValue
    }
  }
  
  public func configure(model: Model) {
    topValueLabel.attributedText = model.topValue?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    bottomValueLabel.attributedText = model.bottomValue?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .trailing
    return stackView
  }()
  private let topValueLabel = UILabel()
  private let bottomValueLabel = UILabel()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(topValueLabel)
    stackView.addArrangedSubview(bottomValueLabel)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
