import UIKit
import TKUIKit

final class OperatorsListShimmerView: UICollectionReusableView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {

  private let cellsContainer = UIView()
  private var cellViews = [OperatorsListShimmerCellView]()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
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
  
  struct Model {}
  func configure(model: Model) {}
  
  func startAnimation() {
    cellViews.forEach { $0.startAnimation() }
  }
}

private extension OperatorsListShimmerView {
  func setup() {
    cellsContainer.backgroundColor = .Background.content.withAlphaComponent(0.48)
    cellsContainer.layer.masksToBounds = true
    cellsContainer.layer.cornerRadius = 16
    
    addSubview(cellsContainer)
    cellsContainer.addSubview(stackView)
    
    (0..<3).forEach { _ in
      let cell = OperatorsListShimmerCellView()
      cellViews.append(cell)
      stackView.addArrangedSubview(cell)
    }
    
    cellsContainer.snp.makeConstraints { make in
      make.top.equalToSuperview()
      make.bottom.equalToSuperview().priority(.high)
      make.leading.equalToSuperview().offset(16)
      make.trailing.equalToSuperview().offset(-16).priority(.high)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
  }
}

private final class OperatorsListShimmerCellView: UIView {
  
  let contentView = UIView()
  let iconShimmerView = TKShimmerView()
  let titleShimmerView = TKShimmerView()
  let subtitleShimmerView = TKShimmerView()
  let accessoryShimmerView = TKShimmerView()
  
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
    accessoryShimmerView.startAnimation()
  }
  
  private func setup() {
    addSubview(contentView)
    contentView.addSubview(iconShimmerView)
    contentView.addSubview(titleShimmerView)
    contentView.addSubview(subtitleShimmerView)
    contentView.addSubview(accessoryShimmerView)
    
    contentView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    
    iconShimmerView.snp.makeConstraints { make in
      make.width.equalTo(44)
      make.height.equalTo(44)
      make.leading.equalToSuperview().offset(16)
      make.top.equalToSuperview().offset(16)
      make.bottom.equalToSuperview().offset(-16)
    }
    
    titleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(22)
      make.width.equalTo(CGFloat.random(in: 80..<140))
      make.leading.equalTo(iconShimmerView.snp.trailing).offset(16)
      make.top.equalToSuperview().offset(16)
    }
    
    subtitleShimmerView.snp.makeConstraints { make in
      make.height.equalTo(18)
      make.width.equalTo(CGFloat.random(in: 120..<160))
      make.leading.equalTo(titleShimmerView.snp.leading)
      make.bottom.equalToSuperview().offset(-16)
    }
    
    accessoryShimmerView.snp.makeConstraints { make in
      make.width.equalTo(28)
      make.height.equalTo(28)
      make.centerY.equalToSuperview()
      make.trailing.equalToSuperview().offset(-16)
    }
  }
}
