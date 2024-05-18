import SnapKit
import TKUIKit
import UIKit

let iconURL = "https://images.unsplash.com/photo-1583692717320-0c9661d49d9a?q=20&w=2241&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

enum StakingStyle {
  case liquid
  case other
}

struct StackingProvider {
  let iconURL: String
  let title: String
  let subtitle: String
  let badge: String?
  var isSelected: Bool
}

final class RadioButton: UIControl {
  private let imageView = UIImageView()

  override var isSelected: Bool {
    didSet {
      updateSelectionState()
    }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    addSubview(imageView)
    updateSelectionState()

    imageView.snp.makeConstraints { make in
      make.width.equalTo(28)
      make.height.equalTo(28)
    }

    snp.makeConstraints { make in
      make.edges.equalTo(imageView)
    }
  }

  private func updateSelectionState() {
    if isSelected {
      imageView.image = .TKUIKit.Icons.Size28.radioOn
      imageView.tintColor = .Button.primaryBackground
    } else {
      imageView.image = .TKUIKit.Icons.Size28.radioOff
      imageView.tintColor = .Button.tertiaryBackground
    }
  }
}

final class BadgeView: UIView {
  let titleLabel = UILabel()

  init(model: String) {
    super.init(frame: .zero)
    setup(with: model)
  }
  
  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup(with model: String) {
    titleLabel.attributedText = model.uppercased().withTextStyle(
      .body4,
      color: .Accent.green
    )
    layer.cornerRadius = 4
    backgroundColor = .Accent.green.withAlphaComponent(0.16)
    addSubview(titleLabel)

    titleLabel.snp.makeConstraints { make in
      make.leading.equalTo(snp.leading).offset(5)
      make.trailing.equalTo(snp.trailing).offset(-5)
      make.centerY.equalTo(snp.centerY)
    }

    snp.makeConstraints { make in
      make.height.equalTo(20)
    }
  }
}

final class ProviderView: UIView {
  struct Model {
    let title: String
    let subtitle: String
    let badge: String?
  }

  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  var badgeView: BadgeView?

  init(model: Model) {
    super.init(frame: .zero)
    setup(with: model)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(with model: Model) {}

  private func setup(with model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .label1,
      color: .Text.primary
    )
    subtitleLabel.attributedText = model.subtitle.withTextStyle(
      .body2,
      color: .Text.secondary
    )
    subtitleLabel.numberOfLines = 2

    addSubview(titleLabel)
    addSubview(subtitleLabel)

    titleLabel.snp.makeConstraints { make in
      make.top.equalTo(snp.top)
      make.leading.equalTo(snp.leading).offset(16)
      make.trailing.lessThanOrEqualTo(snp.trailing).offset(-16)
    }
    subtitleLabel.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom)
      make.leading.equalTo(snp.leading).offset(16)
      make.trailing.lessThanOrEqualTo(snp.trailing).offset(-16)
      make.bottom.equalTo(snp.bottom)
    }
    if let badge = model.badge {
      let badgeView = BadgeView(model: badge)
      addSubview(badgeView)
      badgeView.snp.makeConstraints { make in
        make.leading.equalTo(titleLabel.snp.trailing).offset(6)
        make.trailing.lessThanOrEqualTo(snp.trailing).offset(-16)
        make.centerY.equalTo(titleLabel.snp.centerY)
      }
    }

    snp.makeConstraints { _ in
//      make.edges.equalTo(self)
//      make.top.equalTo(titleLabel.snp.top)
//      make.leading.equalTo(titleLabel.snp.leading)
//      make.trailing.equalTo(titleLabel.snp.trailing)
//      make.bottom.equalTo(titleLabel.snp.bottom)
    }
  }
}

final class StackingRow: UIView {
  struct Model {
    let provider: StackingProvider
    let hasSeparator: Bool
    let style: StakingStyle
  }

  let iconView = UIImageView()
  let horizontalStack = UIStackView()
  let verticalStack = UIStackView()
  var radioButton: RadioButton?
  let providerView: ProviderView

  init(model: Model) {
    self.providerView = ProviderView(model: .init(
      title: model.provider.title,
      subtitle: model.provider.subtitle,
      badge: model.provider.badge
    ))
    super.init(frame: .zero)
    setup(with: model)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup(with model: Model) {
    iconView.kf.setImage(with: URL(string: model.provider.iconURL))
    addSubview(horizontalStack)

    iconView.clipsToBounds = true
    iconView.layer.cornerRadius = 22

    verticalStack.axis = .vertical
    verticalStack.spacing = 0
    verticalStack.alignment = .top
    verticalStack.distribution = .fill
    verticalStack.isLayoutMarginsRelativeArrangement = true
    verticalStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

    horizontalStack.addArrangedSubview(iconView)
    horizontalStack.addArrangedSubview(providerView)

    horizontalStack.spacing = 0
    horizontalStack.alignment = .center
    horizontalStack.distribution = .fill

    horizontalStack.isLayoutMarginsRelativeArrangement = true
    horizontalStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

    if model.style == .liquid {
      let radio = RadioButton()
      addSubview(radio)
      radio.isSelected = model.provider.isSelected
      radioButton = radio
      horizontalStack.addArrangedSubview(radio)
    } else if model.style == .other {
      let chevron = UIImageView(image: .TKUIKit.Icons.Size16.chevronRight)
      chevron.tintColor = .Icon.tertiary
      horizontalStack.addArrangedSubview(chevron)
      chevron.snp.makeConstraints { make in
        make.width.equalTo(16)
        make.height.equalTo(16)
      }
    }
    if model.hasSeparator {
      let separatorView = TKSeparatorView()
      separatorView.color = .Separator.common
      addSubview(separatorView)
      separatorView.snp.makeConstraints { make in
        make.height.equalTo(0.5)
        make.leading.equalTo(snp.leading).offset(16)
        make.trailing.equalTo(snp.trailing)
        make.bottom.equalTo(snp.bottom)
      }
    }

    iconView.snp.makeConstraints { make in
      make.width.equalTo(44)
      make.height.equalTo(44)
    }

    horizontalStack.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }

    snp.makeConstraints { make in
      make.height.equalTo(96)
    }
  }
}

final class StakingView: UIView {
  struct Model {
    let title: String
    let providers: [StackingProvider]
    let style: StakingStyle
  }

  let titleLabel = UILabel()
  let liquidOptionsView = UIStackView()

  init(model: Model) {
    super.init(frame: .zero)
    setup(with: model)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc
  private func handleRowTap(_ row: StackingRow) {
    print("did tap \(row)")
  }

  private func setup(with model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .h3,
      color: .Text.primary
    )

    addSubview(titleLabel)
    addSubview(liquidOptionsView)

    liquidOptionsView.alignment = .fill
    liquidOptionsView.distribution = .fillEqually
    liquidOptionsView.spacing = 0
    liquidOptionsView.axis = .vertical
    liquidOptionsView.backgroundColor = .Background.content
    liquidOptionsView.layer.cornerRadius = 16

    for (idx, provider) in model.providers.enumerated() {
      let row = StackingRow(model: .init(provider: provider, hasSeparator: idx != model.providers.endIndex - 1, style: model.style))
      liquidOptionsView.addArrangedSubview(row)
      row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleRowTap)))
    }

    titleLabel.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.leading.equalTo(self)
      make.trailing.equalTo(self)
    }

    liquidOptionsView.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom).offset(16)
      make.horizontalEdges.equalTo(self)
    }

    snp.makeConstraints { make in
//      make.width.equalTo(self)
      make.bottom.equalTo(liquidOptionsView.snp.bottom)
    }
  }
}
