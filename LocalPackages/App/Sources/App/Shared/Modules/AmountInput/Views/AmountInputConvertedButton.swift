import UIKit
import TKUIKit

final class AmountInputConvertedButton: UIControl {
  
  struct Configuration {
    let text: String
    let symbolConfiguration: AmountInputSymbolView.Configuration
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  override var isHighlighted: Bool {
    didSet {
      borderView.alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  private let label = UILabel()
  private let symbolView = AmountInputSymbolView()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.spacing = 4
    stackView.axis = .horizontal
    return stackView
  }()
  private let borderView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    borderView.layer.cornerRadius = bounds.height/2
  }
  
  private func setup() {
    borderView.isUserInteractionEnabled = false
    
    borderView.layer.borderWidth = 1.5
    borderView.layer.borderColor = UIColor.Button.tertiaryBackground.cgColor
    borderView.layer.cornerCurve = .continuous
    
    addSubview(borderView)
    borderView.addSubview(stackView)
    stackView.addArrangedSubview(label)
    stackView.addArrangedSubview(symbolView)
    setupConstraints()
  }
  
  private func setupConstraints() {
    borderView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(borderView).inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else {
      label.text = nil
      symbolView.configuration = nil
      return
    }
    
    label.attributedText = configuration.text.withTextStyle(
      .body1,
      color: .Text.secondary
    )
    symbolView.configuration = configuration.symbolConfiguration
  }
}
