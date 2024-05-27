import UIKit
import SnapKit
import TKUIKit

final class SwapConfirmationView: UIView {

  let headerLabel = UILabel()

  let containerView = UIView()

  var sendView = SwapInputView(state: .send)
  var receiveView = SwapInputView(state: .receive)
  let detailsView = SwapDetailsView()

  let buttonsView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 16
    stackView.distribution = .fillEqually
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0, leading: 16, bottom: 0, trailing: 16
    )
    return stackView
  }()

  let confirmButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )

  let cancelButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
  )

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
    setupConstraints()
  }
}

private extension SwapConfirmationView {
  func setup() {
    containerView.backgroundColor = .Background.page
    addSubview(containerView)

    containerView.addSubview(headerLabel)
    containerView.addSubview(sendView)
    containerView.addSubview(receiveView)
    containerView.addSubview(detailsView)

    containerView.addSubview(buttonsView)
    buttonsView.addArrangedSubview(cancelButton)
    buttonsView.addArrangedSubview(confirmButton)

    sendView.readonly = true
    receiveView.readonly = true
    sendView.updateViewsForReadonly(animated: false)
    receiveView.updateViewsForReadonly(animated: false)

    receiveView.backgroundView.setState(.bottomMerge, animated: false)
    detailsView.backgroundView.setState(.topMerge, animated: false)

    detailsView.statusLabel.isHidden = true
    detailsView.loader.isHidden = true
    detailsView.hideRate()
    detailsView.contentView.alpha = 1
  }

  func setupConstraints() {
    containerView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    headerLabel.snp.makeConstraints { make in
      make.top.equalTo(self).offset(14)
      make.left.right.equalTo(self)
    }

    sendView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(64)
      make.left.right.equalTo(self).inset(16).priority(.high)
      make.width.equalTo(self).inset(16)
      make.height.equalTo(108)
    }

    receiveView.snp.makeConstraints { make in
      make.top.equalTo(sendView.snp.bottom).offset(8)
      make.left.right.equalTo(self).inset(16).priority(.high)
      make.width.equalTo(self).inset(16)
      make.height.equalTo(108)
    }

    detailsView.snp.makeConstraints { make in
      make.top.equalTo(receiveView.snp.bottom)
      make.left.right.equalTo(self).inset(16).priority(.high)
      make.width.equalTo(self).inset(16)
      make.height.equalTo(SwapView.maxDetailsHeight - 48)
    }

    buttonsView.snp.makeConstraints { make in
      make.bottom.equalTo(safeAreaLayoutGuide)
      make.left.right.equalTo(self)
    }
  }
}
