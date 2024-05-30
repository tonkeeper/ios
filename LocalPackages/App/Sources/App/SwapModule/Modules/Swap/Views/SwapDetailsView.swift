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

  private let providerDetails = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(items: [SwapDetailsView.Item], oneTokenPrice: String) {
    rateLabel.attributedText = oneTokenPrice.withTextStyle(.label2, color: .Text.secondary)

    providerDetails.subviews.forEach {
      $0.removeFromSuperview()
    }
    for (index, item) in items.enumerated() {

      let title = UILabel()
      title.attributedText = item.title.withTextStyle(.label2, color: .Text.secondary)
      title.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

      providerDetails.addSubview(title)
      
      let titleWidth: CGFloat = 150
      title.snp.makeConstraints { make in
        if (index == 0 || index == 5) {
          make.top.equalTo(providerDetails).offset(CGFloat(index) * 36 + 8)
        } else {
          make.bottom.equalTo(providerDetails).inset(CGFloat(4 - index) * 36 + 16)
        }
        make.left.equalTo(providerDetails).offset(16)
        make.width.equalTo(titleWidth)
      }

      let value = UILabel()
      value.attributedText = item.value.withTextStyle(
        .label2,
        color: .Text.secondary,
        alignment: .right
      )

      providerDetails.addSubview(value)

      value.snp.makeConstraints { make in
        if (index == 0 || index == 5) {
          make.top.equalTo(providerDetails).offset(CGFloat(index) * 36 + 8)
        } else {
          make.bottom.equalTo(providerDetails).inset(CGFloat(4 - index) * 36 + 16)
        }
        make.left.equalTo(providerDetails).offset(titleWidth + 8)
        make.right.equalTo(providerDetails).inset(16)
      }
    }
  }

  func hideRate() {
    rateLabel.isHidden = true
    divider2.alpha = 0

    providerDetails.snp.remakeConstraints { make in
      make.top.equalTo(self).offset(8)
      make.right.left.equalTo(self)
      make.bottom.equalTo(contentView)
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
    contentView.addSubview(providerDetails)

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
    providerDetails.snp.makeConstraints { make in
      make.top.equalTo(contentView).offset(56)
      make.right.left.equalTo(contentView)
      make.bottom.equalTo(contentView)
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

