import UIKit
import TKUIKit
import SnapKit

// MARK: - ShimmerView

final class SwapTokenListShimmerView: UICollectionReusableView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {
  
  private let suggestedTitleShimmerView = TitleHeaderShimmerView()
  private let otherTitleShimmerView = TitleHeaderShimmerView()
  
  private var suggestedTokenButtonsShimmerViews = [SwapTokenButtonShimmerView]()
  private let suggestedTokenButtonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    return stackView
  }()
  
  private let otherCellsContainer = UIView()
  private var otherCellsShimmerViews = [SwapTokenListShimmerCellView]()
  private let otherCellsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return systemLayoutSizeFitting(
      size,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    )
  }
  
  func startAnimation() {
    suggestedTitleShimmerView.startAnimation()
    otherTitleShimmerView.startAnimation()
    suggestedTokenButtonsShimmerViews.forEach { $0.startAnimation() }
    otherCellsShimmerViews.forEach { $0.startAnimation() }
  }
  
  struct Model {}
  
  func configure(model: Model) {}
  
  private func setup() {
    otherCellsContainer.layer.cornerRadius = 16
    otherCellsContainer.layer.masksToBounds = true
    otherCellsContainer.backgroundColor = .Background.content.withAlphaComponent(0.48)
    
    addSubview(suggestedTitleShimmerView)
    addSubview(suggestedTokenButtonsStackView)
    addSubview(otherTitleShimmerView)
    addSubview(otherCellsContainer)
    otherCellsContainer.addSubview(otherCellsStackView)
    
    (0..<2).forEach { _ in
      let shimmerButton = SwapTokenButtonShimmerView()
      suggestedTokenButtonsShimmerViews.append(shimmerButton)
      suggestedTokenButtonsStackView.addArrangedSubview(shimmerButton)
    }
    
    (0..<8).forEach { _ in
      let cellShimmer = SwapTokenListShimmerCellView()
      otherCellsShimmerViews.append(cellShimmer)
      otherCellsStackView.addArrangedSubview(cellShimmer)
    }
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    suggestedTitleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleHeaderHeight)
      make.top.left.width.equalTo(self)
    }
    
    suggestedTokenButtonsStackView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.swapTokenButtonHeight)
      make.top.equalTo(suggestedTitleShimmerView.snp.bottom)
      make.left.equalTo(self)
    }
    
    otherTitleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleHeaderHeight)
      make.top.equalTo(suggestedTokenButtonsStackView.snp.bottom).offset(16)
      make.left.width.equalTo(self)
    }
    
    otherCellsContainer.snp.makeConstraints { make in
      make.top.equalTo(otherTitleShimmerView.snp.bottom)
      make.left.right.bottom.equalTo(self)
    }
    
    otherCellsStackView.snp.makeConstraints { make in
      make.edges.equalTo(otherCellsContainer)
    }
  }
}

// MARK: - TitleHeaderShimmerView

private final class TitleHeaderShimmerView: UIView {
  
  private let contentView = UIView()
  private let titleShimmerView = TKShimmerView()
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .titleHeaderHeight)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func startAnimation() {
    titleShimmerView.startAnimation()
  }
  
  private func setup() {
    addSubview(contentView)
    contentView.addSubview(titleShimmerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    contentView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    titleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleHeight)
      make.width.equalTo(CGFloat.random(in: 60...90))
      make.left.equalTo(self).offset(2)
      make.centerY.equalTo(contentView)
    }
  }
}

// MARK: - SwapTokenButtonShimmer

private final class SwapTokenButtonShimmerView: UIView {
  
  private let contentView = UIView()
  private let iconShimmerView = TKShimmerView()
  private let titleShimmerView = TKShimmerView()
  
  override var intrinsicContentSize: CGSize { .init(width: 103, height: .swapTokenButtonHeight) }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func startAnimation() {
    iconShimmerView.startAnimation()
    titleShimmerView.startAnimation()
  }
  
  private func setup() {
    contentView.layer.cornerRadius = 18
    contentView.backgroundColor = .Background.content.withAlphaComponent(0.48)
    
    addSubview(contentView)
    contentView.addSubview(iconShimmerView)
    contentView.addSubview(titleShimmerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    contentView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    iconShimmerView.snp.makeConstraints { make in
      make.width.height.equalTo(28)
      make.left.equalTo(contentView).offset(4)
      make.centerY.equalTo(contentView)
    }
    
    titleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleHeight)
      make.left.equalTo(iconShimmerView.snp.right).offset(8)
      make.right.equalTo(contentView).inset(16)
      make.centerY.equalTo(contentView)
    }
  }
}

// MARK: - SwapTokenListShimmerCell

private final class SwapTokenListShimmerCellView: UIView {
  
  private let contentView = UIView()
  private let iconShimmerView = TKShimmerView()
  private let titleShimmerView = TKShimmerView()
  private let subtitleShimmerView = TKShimmerView()
  private let valueShimmerView = TKShimmerView()
  private let valueSubtitleShimmerView = TKShimmerView()
  
  override var intrinsicContentSize: CGSize { .init(width: UIView.noIntrinsicMetric, height: .otherCellHeight) }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func startAnimation() {
    iconShimmerView.startAnimation()
    titleShimmerView.startAnimation()
    subtitleShimmerView.startAnimation()
    valueShimmerView.startAnimation()
    valueSubtitleShimmerView.startAnimation()
  }
  
  private func setup() {
    iconShimmerView.cornerRadiusRule = .rounded
    
    addSubview(contentView)
    contentView.addSubview(iconShimmerView)
    contentView.addSubview(titleShimmerView)
    contentView.addSubview(subtitleShimmerView)
    contentView.addSubview(valueShimmerView)
    contentView.addSubview(valueSubtitleShimmerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    contentView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    iconShimmerView.snp.makeConstraints { make in
      make.width.height.equalTo(44)
      make.left.equalTo(contentView).offset(CGFloat.horizontalPadding)
      make.centerY.equalTo(contentView)
    }
    
    titleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleHeight)
      make.width.equalTo(CGFloat.random(in: 36...60))
      make.left.equalTo(iconShimmerView.snp.right).offset(CGFloat.horizontalPadding)
      make.top.equalTo(contentView).offset(CGFloat.verticalPadding)
    }
    
    subtitleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.subtitleHeight)
      make.width.equalTo(CGFloat.random(in: 50...110))
      make.left.equalTo(titleShimmerView)
      make.bottom.equalTo(contentView).inset(CGFloat.verticalPadding)
    }
    
    valueShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleHeight)
      make.width.equalTo(CGFloat.random(in: 50...60))
      make.right.equalTo(contentView).inset(CGFloat.horizontalPadding)
      make.centerY.equalTo(titleShimmerView)
    }
    
    valueSubtitleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.subtitleHeight)
      make.width.equalTo(CGFloat.random(in: 40...50))
      make.right.equalTo(valueShimmerView)
      make.centerY.equalTo(subtitleShimmerView)
    }
  }
}

private extension CGFloat {
  static let titleHeaderHeight: CGFloat = 48
  static let titleHeight: CGFloat = 20
  static let subtitleHeight: CGFloat = 16
  static let horizontalPadding: CGFloat = 16
  static let verticalPadding: CGFloat = 16
  static let otherCellHeight: CGFloat = 76
  static let swapTokenButtonHeight: CGFloat = 36
}
