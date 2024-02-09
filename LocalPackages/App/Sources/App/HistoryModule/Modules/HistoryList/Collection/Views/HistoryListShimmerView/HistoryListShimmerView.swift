import UIKit
import TKUIKit

final class HistoryListShimmerView: UICollectionReusableView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {

  private let sectionHeaderShimmerView = TKShimmerView()
  private let cellsContainer = UIView()
  private var cellShimmerView = [HistoryListShimmerCellView]()
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
    sectionHeaderShimmerView.startAnimation()
    cellShimmerView.forEach { $0.startAnimation() }
  }
}

private extension HistoryListShimmerView {
  func setup() {
    cellsContainer.backgroundColor = .Background.content.withAlphaComponent(0.48)
    cellsContainer.layer.masksToBounds = true
    cellsContainer.layer.cornerRadius = 16
    
    addSubview(sectionHeaderShimmerView)
    addSubview(cellsContainer)
    cellsContainer.addSubview(stackView)
    
    (0..<3).forEach { _ in
      let cellShimmer = HistoryListShimmerCellView()
      cellShimmerView.append(cellShimmer)
      stackView.addArrangedSubview(cellShimmer)
    }

    sectionHeaderShimmerView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    cellsContainer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      sectionHeaderShimmerView.topAnchor.constraint(equalTo: topAnchor),
      sectionHeaderShimmerView.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
      sectionHeaderShimmerView.heightAnchor.constraint(equalToConstant: 25).withPriority(.defaultHigh),
      sectionHeaderShimmerView.widthAnchor.constraint(equalToConstant: 95),
      
      cellsContainer.topAnchor.constraint(equalTo: sectionHeaderShimmerView.bottomAnchor, constant: 16),
      cellsContainer.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
      cellsContainer.rightAnchor.constraint(equalTo: rightAnchor, constant: -16).withPriority(.defaultHigh),
      cellsContainer.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      
      stackView.topAnchor.constraint(equalTo: cellsContainer.topAnchor),
      stackView.leftAnchor.constraint(equalTo: cellsContainer.leftAnchor),
      stackView.rightAnchor.constraint(equalTo: cellsContainer.rightAnchor).withPriority(.defaultHigh),
      stackView.bottomAnchor.constraint(equalTo: cellsContainer.bottomAnchor).withPriority(.defaultHigh),
    ])
  }
}

private final class HistoryListShimmerCellView: UIView {
  
  let contentView = UIView()
  let iconShimmerView = TKShimmerView()
  let titleShimmerView = TKShimmerView()
  let subtitleShimmerView = TKShimmerView()
  
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
  }
  
  private func setup() {
    addSubview(contentView)
    contentView.addSubview(iconShimmerView)
    contentView.addSubview(titleShimmerView)
    contentView.addSubview(subtitleShimmerView)
    
    contentView.translatesAutoresizingMaskIntoConstraints = false
    iconShimmerView.translatesAutoresizingMaskIntoConstraints = false
    titleShimmerView.translatesAutoresizingMaskIntoConstraints = false
    subtitleShimmerView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
      contentView.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
      contentView.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
      
      iconShimmerView.widthAnchor.constraint(equalToConstant: 44),
      iconShimmerView.heightAnchor.constraint(equalToConstant: 44),
      iconShimmerView.topAnchor.constraint(equalTo: contentView.topAnchor),
      iconShimmerView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      iconShimmerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      
      titleShimmerView.leftAnchor.constraint(equalTo: iconShimmerView.rightAnchor, constant: 16),
      titleShimmerView.topAnchor.constraint(equalTo: iconShimmerView.topAnchor),
      titleShimmerView.widthAnchor.constraint(equalToConstant: CGFloat.random(in: 50..<150)),
      titleShimmerView.heightAnchor.constraint(equalToConstant: 20),
      
      subtitleShimmerView.leftAnchor.constraint(equalTo: iconShimmerView.rightAnchor, constant: 16),
      subtitleShimmerView.bottomAnchor.constraint(equalTo: iconShimmerView.bottomAnchor),
      subtitleShimmerView.widthAnchor.constraint(equalToConstant: CGFloat.random(in: 50..<150)),
      subtitleShimmerView.heightAnchor.constraint(equalToConstant: 20)
    ])
  }
}
