import UIKit
import TKUIKit

final class SwapDetailsView: UIView {

  enum State {
    case notValid
    case updating
    case fixed
  }

  var state: SwapDetailsView.State = .notValid

  let backgroundView = TKBackgroundView()

  let statusLabel = UILabel()
  let loader = TKLoaderView(size: .medium, style: .primary)

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension SwapDetailsView {
  func setup() {
    addSubview(backgroundView)
    addSubview(statusLabel)
    addSubview(loader)

    backgroundColor = .Background.content

    statusLabel.font = TKTextStyle.label1.font
    statusLabel.textColor = .Button.secondaryForeground
    statusLabel.textAlignment = .center

    loader.alpha = 0

    setupConstraints()
  }

  func setupConstraints() {
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
  }
}

