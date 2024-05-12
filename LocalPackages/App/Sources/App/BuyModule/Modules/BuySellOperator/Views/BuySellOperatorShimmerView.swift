import UIKit
import TKUIKit
import SnapKit

// MARK: - ShimmerView

final class BuySellOperatorShimmerView: UICollectionReusableView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {
  private let pickerCellShimmerView = BuySellCurrencyPickerShimmerCellView()
  private var cellShimmerView = [BuySellOperatorShimmerCellView]()
  private let cellsContainer = UIView()
  private let stackView: UIStackView = {
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
    pickerCellShimmerView.startAnimation()
    cellShimmerView.forEach { $0.startAnimation() }
  }
  
  struct Model {}
  
  func configure(model: Model) {}
  
  private func setup() {
    pickerCellShimmerView.backgroundColor = .Background.content.withAlphaComponent(0.48)
    cellsContainer.backgroundColor = .Background.content.withAlphaComponent(0.48)
    
    pickerCellShimmerView.layer.masksToBounds = true
    cellsContainer.layer.masksToBounds = true
    
    pickerCellShimmerView.layer.cornerRadius = 16
    cellsContainer.layer.cornerRadius = 16
    
    addSubview(pickerCellShimmerView)
    addSubview(cellsContainer)
    cellsContainer.addSubview(stackView)
    
    (0..<4).forEach { _ in
      let cellShimmer = BuySellOperatorShimmerCellView()
      cellShimmerView.append(cellShimmer)
      stackView.addArrangedSubview(cellShimmer)
    }
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    pickerCellShimmerView.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.left.equalTo(self)
      make.right.equalTo(self)
      make.height.equalTo(CGFloat.pickerCellHeight)
    }
    
    cellsContainer.snp.makeConstraints { make in
      make.top.equalTo(pickerCellShimmerView.snp.bottom).offset(CGFloat.verticalPadding)
      make.bottom.equalTo(self)
      make.left.equalTo(self)
      make.right.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(cellsContainer)
    }
  }
}

// MARK: - PickerShimmerCell

private final class BuySellCurrencyPickerShimmerCellView: UIView {
  private let contentView = UIView()
  private let titleShimmerView = TKShimmerView()
  private let subtitleShimmerView = TKShimmerView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func startAnimation() {
    titleShimmerView.startAnimation()
    subtitleShimmerView.startAnimation()
  }
  
  private func setup() {
    addSubview(contentView)
    contentView.addSubview(titleShimmerView)
    contentView.addSubview(subtitleShimmerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    contentView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    titleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleHeight)
      make.width.equalTo(42)
      make.left.equalTo(contentView).offset(CGFloat.horizontalPadding)
      make.centerY.equalTo(contentView)
    }
    
    subtitleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.titleHeight)
      make.width.equalTo(CGFloat.random(in: 120...220))
      make.left.equalTo(titleShimmerView.snp.right).offset(8)
      make.centerY.equalTo(contentView)
    }
  }
}

// MARK: - OperatorShimmerCell

private final class BuySellOperatorShimmerCellView: UIView {
  private let contentView = UIView()
  private let iconShimmerView = TKShimmerView()
  private let titleShimmerView = TKShimmerView()
  private let descriptionShimmerView = TKShimmerView()
  private let radioButtonShimmerView = TKShimmerView()
  
  override var intrinsicContentSize: CGSize { .init(width: UIView.noIntrinsicMetric, height: .operatorCellHeight) }
  
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
    descriptionShimmerView.startAnimation()
    radioButtonShimmerView.startAnimation()
  }
  
  private func setup() {
    iconShimmerView.cornerRadiusRule = .fixed(12)
    
    addSubview(contentView)
    contentView.addSubview(iconShimmerView)
    contentView.addSubview(titleShimmerView)
    contentView.addSubview(descriptionShimmerView)
    contentView.addSubview(radioButtonShimmerView)
    
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
      make.width.equalTo(CGFloat.random(in: 90..<110))
      make.left.equalTo(iconShimmerView.snp.right).offset(CGFloat.horizontalPadding)
      make.top.equalTo(contentView).offset(CGFloat.verticalPadding)
    }
    
    descriptionShimmerView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.descriptionHeight)
      make.width.equalTo(150)
      make.left.equalTo(titleShimmerView)
      make.bottom.equalTo(contentView).inset(CGFloat.verticalPadding)
    }
    
    radioButtonShimmerView.snp.makeConstraints { make in
      make.height.width.equalTo(28)
      make.right.equalTo(contentView).inset(CGFloat.horizontalPadding)
      make.centerY.equalTo(contentView)
    }
  }
}

private extension CGFloat {
  static let titleHeight: CGFloat = 20
  static let descriptionHeight: CGFloat = 16
  static let horizontalPadding: CGFloat = 16
  static let verticalPadding: CGFloat = 16
  static let pickerCellHeight: CGFloat = 56
  static let operatorCellHeight: CGFloat = 76
}
