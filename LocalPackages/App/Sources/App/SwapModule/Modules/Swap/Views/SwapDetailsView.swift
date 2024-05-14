import UIKit
import TKUIKit

final class SwapDetailsView: UIView {

  private let backgroundView = TKBackgroundView()

  let statusLabel = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: 56)
  }
}

private extension SwapDetailsView {
  func setup() {
    addSubview(backgroundView)
    addSubview(statusLabel)

    statusLabel.font = TKTextStyle.label1.font
    statusLabel.textColor = .Button.secondaryForeground
    statusLabel.textAlignment = .center

    setupConstraints()
  }

  func setupConstraints() {
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    statusLabel.snp.makeConstraints { make in
      make.verticalEdges.equalTo(self)
      make.horizontalEdges.equalTo(self).inset(16)
    }
  }
}

