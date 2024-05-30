import UIKit
import TKUIKit

final class SlippagePercentButton: TKUIButton<SlippagePercentButtonContentView, TKUIButtonDefaultBackgroundView> {
  
  override var isSelected: Bool {
    didSet {
      guard isSelected != oldValue else { return }
      didUpdateSelectedState()
    }
  }
  
  override var intrinsicContentSize: CGSize { .init(width: UIView.noIntrinsicMetric, height: sizeThatFits(bounds.size).height) }
  
  init() {
    super.init(
      contentView: SlippagePercentButtonContentView(),
      backgroundView: TKUIButtonDefaultBackgroundView(cornerRadius: 16),
      contentHorizontalPadding: 0
    )
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return contentView.sizeThatFits(size)
  }
  
  private func setup () {
    backgroundView.backgroundColor = .Field.background
  }
  
  private func didUpdateSelectedState() {
    let color: UIColor = isSelected ? .Field.activeBorder : .Field.background
    UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState]) {
      self.backgroundView.layer.borderColor = color.cgColor
      self.backgroundView.layer.borderWidth = 1.5
    }
  }
}

final class SlippagePercentButtonContentView: UIView, ConfigurableView {
  
  let titleLabel = UILabel()
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  override var intrinsicContentSize: CGSize { sizeThatFits(bounds.size) }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let padding = UIEdgeInsets.slippagePercentButtonPadding
    var resultSize = titleLabel.sizeThatFits(size)
    resultSize.width += padding.left + padding.right
    resultSize.height += padding.top + padding.bottom
    return resultSize
  }
  
  struct Model {
    let title: String
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(.body1, color: .Text.primary, alignment: .center)
    invalidateIntrinsicContentSize()
  }
  
  private func setup() {
    contentStackView.addArrangedSubview(titleLabel)
    addSubview(contentStackView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    contentStackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets.slippagePercentButtonPadding)
    }
  }
}

private extension UIEdgeInsets {
  static let slippagePercentButtonPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
