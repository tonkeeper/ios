import UIKit
import TKUIKit

final class HistoryEventDetailsScamView: UIView {

  struct Model {
    let title: NSAttributedString
  }

  private let containerView: UIView = {
    let view = UIView()
    view.backgroundColor = .Accent.orange
    view.layer.masksToBounds = true
    view.layer.cornerRadius = 8
    return view
  }()
  private let label = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    containerView.addSubview(label)
    addSubview(containerView)

    label.snp.makeConstraints { make in
      make.top.bottom.equalToSuperview().inset(4)
      make.left.right.equalToSuperview().inset(8)
    }
    containerView.snp.makeConstraints {
      $0.top.bottom.equalToSuperview()
      $0.centerX.equalToSuperview()
    }
  }
}

// MARK: -  ConfigurableView

extension HistoryEventDetailsScamView: ConfigurableView {

  func configure(model: Model) {
    label.attributedText = model.title
  }
}
