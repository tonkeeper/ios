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
    
    public struct Value {
      public let value: String?
      public let numberOfLines: Int
      
      public init(value: String?,
                  numberOfLines: Int = 1) {
        self.value = value
        self.numberOfLines = numberOfLines
      }
    }
    
    public let topValue: Value?
    public let bottomValue: Value?
    
    public init(topValue: Value? = nil, bottomValue: Value? = nil) {
      self.topValue = topValue
      self.bottomValue = bottomValue
    }
  }
  
  public func configure(model: Model) {
    if let topValue = model.topValue {
      topValueLabel.attributedText = topValue.value?.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
      topValueLabel.numberOfLines = topValue.numberOfLines
    } else {
      topValueLabel.attributedText = nil
    }
    
    if let bottomValue = model.bottomValue {
      bottomValueLabel.attributedText = bottomValue.value?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
      bottomValueLabel.numberOfLines = bottomValue.numberOfLines
    } else {
      bottomValueLabel.attributedText = nil
    }
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
    topValueLabel.numberOfLines = 0
    
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
