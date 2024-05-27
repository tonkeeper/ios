import UIKit
import TKUIKit

final class SwapDetailsView: UIView {

  let backgroundView = TKBackgroundView()

  let statusLabel = UILabel()
  let loader = TKLoaderView(size: .medium, style: .primary)

  let contentView = UIView()
  private let divider1 = UIView()
  private let divider2 = UIView()
  private let rateLabel = UILabel()

  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 8,
      leading: 16,
      bottom: 8,
      trailing: 16
    )
    return stackView
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(items: [SwapDetailsView.Item], oneTokenPrice: String) {
    rateLabel.attributedText = oneTokenPrice.withTextStyle(.label2, color: .Text.secondary)

    stackView.arrangedSubviews.forEach {
      stackView.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }
    for item in items {
      let horizontalStack = UIStackView()
      horizontalStack.axis = .horizontal
      horizontalStack.spacing = 0
      horizontalStack.isLayoutMarginsRelativeArrangement = true

      let title = UILabel()
      title.attributedText = item.title.withTextStyle(.label2, color: .Text.secondary)
      let value = UILabel()
      value.attributedText = item.value.withTextStyle(
        .label2,
        color: .Text.secondary,
        alignment: .right
      )

      horizontalStack.addArrangedSubview(title)
      horizontalStack.addArrangedSubview(value)

      stackView.addArrangedSubview(horizontalStack)
    }
  }
}

private extension SwapDetailsView {
  func setup() {
    addSubview(backgroundView)
    addSubview(statusLabel)
    addSubview(loader)

    addSubview(contentView)
    contentView.addSubview(divider1)
    contentView.addSubview(rateLabel)
    contentView.addSubview(divider2)
    contentView.addSubview(stackView)

    statusLabel.font = TKTextStyle.label1.font
    statusLabel.textColor = .Button.secondaryForeground
    statusLabel.textAlignment = .center

    divider1.backgroundColor = .Button.secondaryForeground.withAlphaComponent(0.2)
    divider2.backgroundColor = .Button.secondaryForeground.withAlphaComponent(0.2)

    loader.alpha = 0
    contentView.alpha = 0

    setupConstraints()
  }

  func setupConstraints() {
    let scale = UIApplication.keyWindowScene?.screen.scale ?? 1
    
    backgroundView.snp.makeConstraints { make in
      make.top.right.left.bottom.equalTo(self)
    }
    statusLabel.snp.makeConstraints { make in
      make.verticalEdges.equalTo(self)
      make.horizontalEdges.equalTo(self).inset(16)
    }
    loader.snp.makeConstraints { make in
      make.centerX.equalTo(self)
      make.top.equalTo(self).offset(16)
    }

    contentView.snp.makeConstraints { make in
      make.top.right.left.bottom.equalTo(self)
    }
    divider1.snp.makeConstraints { make in
      make.top.right.left.equalTo(contentView)
      make.height.equalTo(1 / scale)
    }
    rateLabel.snp.makeConstraints { make in
      make.top.equalTo(contentView).offset(14)
      make.left.equalTo(contentView).offset(16)
      make.right.equalTo(contentView).inset(44)
    }
    divider2.snp.makeConstraints { make in
      make.right.left.equalTo(contentView)
      make.top.equalTo(contentView).offset(47)
      make.height.equalTo(1 / scale)
    }
    stackView.snp.makeConstraints { make in
      make.top.equalTo(divider2).offset(8)
      make.right.left.equalTo(self)
    }
  }
}

extension SwapDetailsView {

  struct Item {
    let title: String
    let hint: String?
    let value: String
  }
}

