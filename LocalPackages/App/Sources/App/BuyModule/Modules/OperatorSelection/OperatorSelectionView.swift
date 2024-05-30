import UIKit
import TKUIKit

final class OperatorSelectionView: UIView {
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  
  let continueButton = TKButton()
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
    container.padding = .continueButtonPadding
    return container
  }()

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    collectionView.frame = bounds
  }
}

// MARK: - Private

private extension OperatorSelectionView {
  func setup() {
    collectionView.backgroundColor = .Background.page
    addSubview(collectionView)
    addSubview(continueButtonContainer)
    continueButtonContainer.setViews([continueButton])
    
    continueButtonContainer.snp.makeConstraints { make in
      make.leading.equalToSuperview()
      make.trailing.equalToSuperview()
      make.bottom.equalTo(self.safeAreaLayoutGuide.snp.bottom)
    }
  }
}

private extension UIEdgeInsets {
  static let continueButtonPadding = UIEdgeInsets(
    top: 16,
    left: 16,
    bottom: 16,
    right: 16
  )
}
