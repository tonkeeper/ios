import UIKit
import TKUIKit

final class SwapTokenListView: UIView, ConfigurableView {
  
  var searchBarViewTopOffset: CGFloat = 64 {
    didSet {
      updateSearchBarViewTopOffsetConstraint()
    }
  }
  
  var searchBarContainerHeight: CGFloat {
    searchBar.intrinsicContentSize.height + UIEdgeInsets.searchBarPadding.top + UIEdgeInsets.searchBarPadding.bottom
  }
  
  var contentInsetBottom: CGFloat {
    closeButtonSize.height + .verticalPadding
  }
  
  let titleView = ModalTitleView()
  let searchBar = SearchBar()
  let searchBarContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = UIView()
    container.backgroundColor = .Background.page
    container.padding = .searchBarPadding
    return container
  }()
  
  let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: .init())
  let noSearchResultsLabel = UILabel()
  
  let closeButtonSize = TKActionButtonSize.large
  let closeButtonBackgroundView = UIView()
  lazy var closeButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .secondary,
      size: closeButtonSize
    )
  )
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Button {
      let title: String
      let action: (() -> Void)?
    }
    
    let title: ModalTitleView.Model
    let noSearchResultsTitle: NSAttributedString
    let closeButton: Button
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.title)
    noSearchResultsLabel.attributedText = model.noSearchResultsTitle
    closeButton.configuration.content.title = .plainString(model.closeButton.title)
    closeButton.configuration.action = model.closeButton.action
  }
}

// MARK: - Setup

private extension SwapTokenListView {
  func setup() {
    noSearchResultsLabel.isHidden = true
    closeButtonBackgroundView.backgroundColor = .Background.page
    
    searchBarContainer.setViews([searchBar])
    
    addSubview(collectionView)
    addSubview(noSearchResultsLabel)
    addSubview(searchBarContainer)
    addSubview(closeButtonBackgroundView)
    addSubview(closeButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    noSearchResultsLabel.snp.makeConstraints { make in
      make.centerX.equalTo(self)
      make.top.equalTo(searchBarContainer.snp.bottom).offset(64)
    }
    
    searchBarContainer.snp.makeConstraints { make in
      make.left.equalTo(self)
      make.right.equalTo(self)
      make.top.equalTo(self).offset(searchBarViewTopOffset)
    }
    
    closeButtonBackgroundView.snp.makeConstraints { make in
      make.left.right.bottom.equalTo(self)
      make.top.equalTo(closeButton).offset(-CGFloat.verticalPadding)
    }
    
    closeButton.snp.makeConstraints { make in
      make.left.equalTo(self).offset(CGFloat.horizontalPadding)
      make.right.equalTo(self).inset(CGFloat.horizontalPadding)
      make.bottom.equalTo(safeAreaLayoutGuide).inset(CGFloat.verticalPadding)
    }
  }
  
  func updateSearchBarViewTopOffsetConstraint() {
    searchBarContainer.snp.updateConstraints { make in
      make.top.equalTo(self).offset(searchBarViewTopOffset)
    }
  }
}

private extension CGFloat {
  static let horizontalPadding: CGFloat = 16
  static let verticalPadding: CGFloat = 16
}

private extension UIEdgeInsets {
  static let searchBarPadding = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
}
