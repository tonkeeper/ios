import UIKit
import TKUIKit

final class BuyListSectionHeaderView: UICollectionReusableView, ConfigurableView, ReusableView {
  struct Model {
    let titleViewModel: TKListTitleView.Model
    let assetsViewModel: BuyListSectionHeaderAssetsView.Model
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.titleViewModel)
    assetsView.configure(model: model.assetsViewModel)
  }
  
  private let titleView = TKListTitleView()
  private let assetsView = BuyListSectionHeaderAssetsView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    addSubview(titleView)
    addSubview(assetsView)
    
    titleView.setContentHuggingPriority(.required, for: .horizontal)
    
    titleView.snp.makeConstraints { make in
      make.left.equalTo(self)
      make.centerY.equalTo(self)
    }
    
    assetsView.snp.makeConstraints { make in
      make.centerY.equalTo(self)
      make.left.equalTo(titleView.snp.right).offset(6)
      make.right.lessThanOrEqualTo(self)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class BuyListSectionHeaderAssetsView: TKView, ConfigurableView {
  
  struct Model {
    struct Asset {
      let image: UIImage?
    }
    let assets: [Asset]
  }
  
  func configure(model: Model) {
    iconsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    let visibleAssets = model.assets.prefix(.maximumIcons)
    let invisibleCount = model.assets.count - visibleAssets.count
    
    visibleAssets.enumerated().forEach { index, asset in
      let view = BuyListSectionHeaderAssetsIconView()
      view.configure(model: BuyListSectionHeaderAssetsIconView.Model(image: asset.image))
      iconsStackView.addArrangedSubview(view)
      view.layer.zPosition = CGFloat(visibleAssets.count - index)
    }
    
    if invisibleCount > 0 {
      amountView.isHidden = false
      amountView.configure(model: BuyListSectionHeaderAssetsAmountView.Model(amount: invisibleCount))
    } else {
      amountView.isHidden = true
    }
  }
  
  private let amountView = BuyListSectionHeaderAssetsAmountView()
  private let iconsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.spacing = -6
    stackView.axis = .horizontal
    return stackView
  }()

  override func setup() {
    super.setup()
    
    addSubview(iconsStackView)
    addSubview(amountView)
    
    iconsStackView.snp.makeConstraints { make in
      make.top.left.bottom.equalTo(self)
    }
    
    amountView.snp.makeConstraints { make in
      make.centerY.equalTo(iconsStackView)
      make.left.equalTo(iconsStackView.snp.right).offset(6)
      make.right.equalTo(self)
    }
  }
}

private final class BuyListSectionHeaderAssetsIconView: TKView, ConfigurableView {
  
  struct Model {
    let image: UIImage?
  }
  
  func configure(model: Model) {
    imageView.image = model.image
  }
  
  private let imageView = UIImageView()
  
  override func setup() {
    super.setup()
    
    addSubview(imageView)
    
    backgroundColor = .Background.page
    layer.cornerRadius = 10
    layer.masksToBounds = true
    imageView.layer.cornerRadius = 10
    imageView.layer.masksToBounds = true
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    imageView.snp.makeConstraints { make in
      make.width.height.equalTo(20)
      make.edges.equalTo(self).inset(1.5)
    }
  }
}

private final class BuyListSectionHeaderAssetsAmountView: TKView, ConfigurableView {
  
  struct Model {
    let amount: Int
  }
  
  func configure(model: Model) {
    let text = "+\(model.amount)".withTextStyle(
      .body3,
      color: .Text.secondary,
      alignment: .center,
      lineBreakMode: .byTruncatingTail
    )
    label.attributedText = text
  }
  
  private let label = UILabel()
  
  override func setup() {
    super.setup()
    
    backgroundColor = .Background.contentTint
    layer.cornerRadius = 10
    layer.cornerCurve = .continuous
    
    addSubview(label)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    label.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 7))
    }
  }
}

private extension Int {
  static let maximumIcons: Int = 3
}
