import SnapKit
import TKUIKit
import UIKit

final class WalletBalanceView: UIView, ConfigurableView {
  let headerView = WalletBalanceHeaderView()

  let collectionView = TKUICollectionView(
    frame: .zero,
    collectionViewLayout: UICollectionViewLayout()
  )

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  struct Model {
//    let headerViewModel: WalletBalanceHeaderView.Model
  }

  func configure(model: Model) {
//    headerView.configure(model: model.headerViewModel)
  }
}

final class TagView: UIView {
  struct Model {
    let icon: UIImage
    let title: String
  }

  let imageView: UIImageView
  let titleLabel = UILabel()

  init(model: Model) {
    self.imageView = UIImageView(image: model.icon)
    super.init(frame: .zero)
    setup(with: model)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup(with model: Model) {
    addSubview(imageView)
    addSubview(titleLabel)

    imageView.tintColor = .Button.secondaryForeground
    backgroundColor = .Button.secondaryBackground
    layer.cornerRadius = 18

    imageView.setContentHuggingPriority(.required, for: .horizontal)
    titleLabel.setContentHuggingPriority(.required, for: .horizontal)
    setContentHuggingPriority(.required, for: .horizontal)

    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .horizontal)

    titleLabel.attributedText = model.title.withTextStyle(
      .label2,
      color: .Button.secondaryForeground
    )

    imageView.snp.makeConstraints { make in
      make.width.equalTo(16)
      make.height.equalTo(16)
      make.leading.equalTo(snp.leading).offset(16)
      make.centerY.equalTo(snp.centerY)
    }

    titleLabel.snp.makeConstraints { make in
      make.leading.equalTo(imageView.snp.trailing).offset(8)
      make.centerY.equalTo(snp.centerY)
      make.trailing.equalTo(snp.trailing).offset(-16)
    }

    snp.makeConstraints { make in
      make.height.equalTo(36)
    }
  }
}

final class HorizontalStackView: UIView {
  var spacing: CGFloat = 0
  private var maxX: CGFloat = 0

  override func addSubview(_ view: UIView) {
    super.addSubview(view)
    view.frame.origin.y = 0
    view.frame.origin.x = maxX
    maxX += view.bounds.width + spacing
  }

  override var intrinsicContentSize: CGSize {
    var offset: CGFloat = 0
    let size = subviews.reduce(into: CGSize.zero) { partialResult, view in
      offset += view.bounds.width
      partialResult.height = max(partialResult.height, view.bounds.height)
      partialResult.width = offset
      offset += spacing
    }
    return size
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    var offset: CGFloat = 0
    for v in subviews {
      v.frame.origin.y = 0
      v.frame.origin.x = offset
      offset = v.bounds.width + spacing
    }
    maxX = offset
  }

  func canFit(view: UIView) -> Bool {
    let availableSpace = bounds.width - maxX
    return availableSpace >= view.bounds.width
  }
}

final class TagsListView: UIView {
  struct Model {
    let tags: [TagView.Model]
  }

  let verticalStackView = UIStackView()
  private var previousWidth: CGFloat = 0
  private let tags: [TagView.Model]

  init(model: Model) {
    self.tags = model.tags
    super.init(frame: .zero)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    addSubview(verticalStackView)
    verticalStackView.axis = .vertical
    verticalStackView.spacing = 8
    verticalStackView.isLayoutMarginsRelativeArrangement = true
    verticalStackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
    verticalStackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.height.greaterThanOrEqualTo(48)
      make.width.greaterThanOrEqualTo(48)
    }
  }

  override func layoutSubviews() {
    if bounds.size.width == previousWidth {
      super.layoutSubviews()
      return
    }
    previousWidth = bounds.size.width
    let availableWidth: CGFloat = bounds.size.width - (verticalStackView.layoutMargins.left + verticalStackView.layoutMargins.right)
    let makeRow: () -> HorizontalStackView = {
      let row = HorizontalStackView()
      row.frame.size.width = availableWidth
      row.spacing = 8
      return row
    }
    verticalStackView.subviews.forEach(verticalStackView.removeArrangedSubview(_:))
    var currentRow: HorizontalStackView = makeRow()
    verticalStackView.addArrangedSubview(currentRow)
    for tagModel in tags {
      let tagView = TagView(model: tagModel)
      tagView.setNeedsLayout()
      tagView.layoutIfNeeded()
      if !currentRow.canFit(view: tagView) {
        currentRow = makeRow()
        verticalStackView.addArrangedSubview(currentRow)
        // TODO: We intentionally don't bother with views that larger than container width here...
      }
      currentRow.addSubview(tagView)
    }
    super.layoutSubviews()
  }
}

struct StakingInfo {
  let title: String
  let value: String
  let badge: String?
}

final class StackingInfoRow: UIView {
  struct Model {
    let info: StakingInfo
  }

  let titleLabel = UILabel()
  let subtitleLabel = UILabel()

  init(model: Model) {
    super.init(frame: .zero)
    setup(with: model)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup(with model: Model) {
    addSubview(titleLabel)
    addSubview(subtitleLabel)

    titleLabel.attributedText = model.info.title.withTextStyle(
      .body2,
      color: .Text.secondary
    )
    subtitleLabel.attributedText = model.info.value.withTextStyle(
      .body2,
      color: .Text.primary
    )

    titleLabel.snp.makeConstraints { make in
      make.centerY.equalTo(snp.centerY)
      make.leading.equalTo(snp.leading)
    }
    subtitleLabel.snp.makeConstraints { make in
      make.centerY.equalTo(titleLabel.snp.centerY)
      make.trailing.equalTo(snp.trailing)
    }
    snp.makeConstraints { make in
      make.height.equalTo(36)
    }
    if let badge = model.info.badge {
      let badgeView = BadgeView(model: badge)
      addSubview(badgeView)
      badgeView.snp.makeConstraints { make in
        make.leading.equalTo(titleLabel.snp.trailing).offset(6)
        make.centerY.equalTo(titleLabel.snp.centerY)
      }
      subtitleLabel.snp.makeConstraints { make in
        make.leading.greaterThanOrEqualTo(badgeView.snp.trailing).offset(6)
      }
    } else {
      subtitleLabel.snp.makeConstraints { make in
        make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(6)
      }
    }
  }
}

final class StakingInfoView: UIView {
  struct Model {
    let info: [StakingInfo]
  }

  let stackView = UIStackView()

  init(model: Model) {
    super.init(frame: .zero)
    setup(with: model)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc
  private func handleRowTap(_ row: StackingInfoRow) {
    print("did tap \(row)")
  }

  private func setup(with model: Model) {
    addSubview(stackView)

    stackView.alignment = .fill
    stackView.distribution = .fillEqually
    stackView.spacing = 0
    stackView.axis = .vertical
    stackView.backgroundColor = .Background.content
    stackView.layer.cornerRadius = 16
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

    for info in model.info {
      let row = StackingInfoRow(model: .init(info: info))
      stackView.addArrangedSubview(row)
      row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleRowTap)))
    }
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}

private extension WalletBalanceView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page

//    addSubview(headerView)
    addSubview(collectionView)

    let tagCollection = TagsListView(model: .init(
      tags: [
        .init(icon: .TKUIKit.Icons.Size16.globe, title: "tonstakers.com"),
        .init(icon: .TKUIKit.Icons.Size16.twitter, title: "Twitter"),
        .init(icon: .TKUIKit.Icons.Size16.telegram, title: "Community"),
        .init(icon: .TKUIKit.Icons.Size16.magnifyingGlass, title: "tonviewer.com"),
      ]
    ))
    addSubview(tagCollection)
//    tagCollection.setNeedsLayout()
//    tagCollection.layoutIfNeeded()

    tagCollection.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(16)
      make.leading.equalTo(snp.leading)
      make.trailing.equalTo(snp.trailing)
    }

    let infoView = StakingInfoView(model: .init(
      info: [
        .init(title: "APY", value: "≈ 5.01%", badge: "MAX"),
        .init(title: "Minimal deposit", value: "1 TON", badge: nil),
      ]
    ))
    addSubview(infoView)
    infoView.snp.makeConstraints { make in
        make.top.equalTo(tagCollection.snp.bottom).offset(16)
        make.leading.equalTo(snp.leading)
        make.trailing.equalTo(snp.trailing)
      }


//    let tagView = TagView(model: .init(icon: .TKUIKit.Icons.Size16.globe, title: "tonstakers.com"))
//    tagView.setNeedsLayout()
//    tagView.layoutIfNeeded()
//    print(tagView.frame, tagView.bounds.size)
//    addSubview(tagView)

//    tagView.snp.makeConstraints { make in
//      make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(64)
//      make.centerX.equalTo(snp.centerX)
    ////      make.leading.equalTo(snp.leading)
    ////      make.trailing.equalTo(snp.trailing)
//    }

    collectionView.snp.makeConstraints { make in
      make.top.equalTo(infoView.snp.bottom).offset(16)
      make.leading.equalTo(snp.leading)
      make.trailing.equalTo(snp.trailing)
      make.bottom.equalTo(snp.bottom)
    }

    setupConstraints()
  }

  func setupConstraints() {
//    headerView.snp.makeConstraints { make in
//      make.left.right.equalTo(self)
//      make.top.equalTo(safeAreaLayoutGuide)
//    }

//    collectionView.snp.makeConstraints { make in
//      make.edges.equalTo(self)
//    }

//    collectionView.translatesAutoresizingMaskIntoConstraints = false
//
//    NSLayoutConstraint.activate([
//      collectionView.topAnchor.constraint(equalTo: topAnchor),
//      collectionView.leftAnchor.constraint(equalTo: leftAnchor),
//      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
//      collectionView.rightAnchor.constraint(equalTo: rightAnchor)
//    ])
  }
}
