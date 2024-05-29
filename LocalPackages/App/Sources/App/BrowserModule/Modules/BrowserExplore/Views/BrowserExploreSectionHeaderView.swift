import UIKit
import TKUIKit
import TKLocalize

final class BrowserExploreSectionHeaderView: UICollectionReusableView, ReusableView, ConfigurableView {
  let titleLabel = UILabel()
  let allButton = UIButton()
  private let stackView = UIStackView()
  
  private var allTapAction: (() -> Void)?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 56)
  }
  
  struct Model {
    let title: String
    let isAllHidden: Bool
    let allTapAction: (() -> Void)?
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .h3,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    allButton.isHidden = model.isAllHidden
    allTapAction = model.allTapAction
  }
}

private extension BrowserExploreSectionHeaderView {
  func setup() {
    backgroundColor = .Background.page
    
    stackView.axis = .horizontal
    stackView.spacing = 16
    
    allButton.setAttributedTitle(
      TKLocales.Browser.List.all.withTextStyle(
        .label1,
        color: .Accent.blue
      ),
      for: .normal
    )
    allButton.setAttributedTitle(
      TKLocales.Browser.List.all.withTextStyle(
        .label1,
        color: .Accent.blue.withAlphaComponent(0.48)
      ),
      for: .highlighted
    )
    allButton.addAction(UIAction(handler: { [weak self] _ in
      self?.allButtonAction()
    }), for: .touchUpInside)
    
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(allButton)
    
    allButton.setContentHuggingPriority(.required, for: .horizontal)
    titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.left.bottom.equalTo(self).priority(.medium)
      make.right.equalTo(self).inset(18).priority(.medium)
    }
  }
  
  func allButtonAction() {
    allTapAction?()
  }
}
