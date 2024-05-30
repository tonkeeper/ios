import UIKit
import TKUIKit

// MARK: - SwapInfoContainerView

final class SwapInfoContainerView: UIView, ConfigurableView {
  
  private let priceImpactRow = SwapInfoRow()
  private let minimumRecievedRow = SwapInfoRow()
  private let liquidityProviderFeeRow = SwapInfoRow()
  private let blockchainFeeRow = SwapInfoRow()
  private let routeRow = SwapInfoRow()
  private let providerRow = SwapInfoRow()
  
  private let contentView = UIView()
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.distribution = .fill
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
    let rowCount: CGFloat = 6
    let height: CGFloat = .rowHeight * rowCount + .containerVerticalPadding * 2
    return CGSize(width: size.width, height: height)
  }
  
  struct Model {
    let priceImpact: SwapInfoRow.Model
    let minimumRecieved: SwapInfoRow.Model
    let liquidityProviderFee: SwapInfoRow.Model
    let blockchainFee: SwapInfoRow.Model
    let route: SwapInfoRow.Model
    let provider: SwapInfoRow.Model
  }
  
  func configure(model: Model) {
    priceImpactRow.configure(model: model.priceImpact)
    minimumRecievedRow.configure(model: model.minimumRecieved)
    liquidityProviderFeeRow.configure(model: model.liquidityProviderFee)
    blockchainFeeRow.configure(model: model.blockchainFee)
    routeRow.configure(model: model.route)
    providerRow.configure(model: model.provider)
  }
}

private extension SwapInfoContainerView {
  func setup() {
    contentStackView.addArrangedSubview(priceImpactRow)
    contentStackView.addArrangedSubview(minimumRecievedRow)
    contentStackView.addArrangedSubview(liquidityProviderFeeRow)
    contentStackView.addArrangedSubview(blockchainFeeRow)
    contentStackView.addArrangedSubview(routeRow)
    contentStackView.addArrangedSubview(providerRow)
    
    contentView.addSubview(contentStackView)
    addSubview(contentView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    contentStackView.snp.makeConstraints { make in
      make.left.right.equalTo(contentView)
      make.top.bottom.equalTo(contentView).inset(CGFloat.containerVerticalPadding)
    }
  }
}

// MARK: - SwapInfoRow

final class SwapInfoRow: UIView, ConfigurableView {
  
  private let infoLabel = InfoLabel()
  private let valueLabel = UILabel()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 12
    stackView.distribution = .fill
    return stackView
  }()
  
  override var intrinsicContentSize: CGSize { .init(width: UIView.noIntrinsicMetric, height: .rowHeight) }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let infoLabel: InfoLabel.Model
    let value: NSAttributedString
  }
  
  func configure(model: Model) {
    infoLabel.configure(model: model.infoLabel)
    valueLabel.attributedText = model.value
    
    infoLabel.snp.remakeConstraints { make in
      make.width.equalTo(infoLabel.sizeThatFits(bounds.size).width).priority(.required)
    }
  }
  
  private func setup() {
    valueLabel.numberOfLines = 2
    
    contentStackView.addArrangedSubview(infoLabel)
    contentStackView.addArrangedSubview(valueLabel)
    addSubview(contentStackView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    infoLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    valueLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
    
    contentStackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets.infoRowContentPadding)
    }
    
    infoLabel.snp.makeConstraints { make in
      make.width.equalTo(infoLabel.sizeThatFits(bounds.size).width).priority(.required)
    }
  }
}

// MARK: - InfoLabel

public final class InfoLabel: UIView, ConfigurableView {
  
  private let label = UILabel()
  private let infoButton = TKButton(configuration: .infoButtonConfiguration())
  
  public override var intrinsicContentSize: CGSize { sizeThatFits(bounds.size) }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let labelSize = label.sizeThatFits(bounds.size)
    let labelOrigin = CGPoint(x: 0, y: bounds.height / 2 - labelSize.height / 2)
    let infoButtonSize = infoButton.sizeThatFits(bounds.size)
    let infoButtonOrigin = CGPoint(x: labelSize.width, y: bounds.height / 2 - infoButtonSize.height / 2)
    
    label.frame = CGRect(origin: labelOrigin, size: labelSize)
    infoButton.frame = CGRect(origin: infoButtonOrigin, size: infoButtonSize)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let labelSize = label.sizeThatFits(size)
    let infoButtonWidth = infoButton.isHidden ? 0 : infoButton.sizeThatFits(size).width
    let width = labelSize.width + infoButtonWidth
    let height = labelSize.height
    return CGSize(width: width, height: height)
  }
  
  public struct Model {
    struct InfoButton {
      let action: (() -> Void)?
    }
    
    let title: NSAttributedString
    let infoButton: InfoButton?
  }
  
  public func configure(model: Model) {
    label.attributedText = model.title
    
    if let infoButton = model.infoButton {
      self.infoButton.configuration.action = infoButton.action
    } else {
      self.infoButton.isHidden = true
    }
    
    setNeedsLayout()
  }
  
  private func setup() {
    addSubview(label)
    addSubview(infoButton)
  }
}

private extension TKButton.Configuration {
  static func infoButtonConfiguration() -> TKButton.Configuration {
    var configuration = TKButton.Configuration.fiedClearButtonConfiguration()
    configuration.content.icon = .TKUIKit.Icons.Size16.informationCircle
    configuration.iconTintColor = .Icon.tertiary
    configuration.contentPadding = .init(top: 2, left: 4, bottom: 2, right: 2)
    configuration.padding = .zero
    return configuration
  }
}

private extension CGFloat {
  static let containerVerticalPadding: CGFloat = 8
  static let rowHeight: CGFloat = 36
}

private extension UIEdgeInsets {
  static let infoRowContentPadding: UIEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
}
