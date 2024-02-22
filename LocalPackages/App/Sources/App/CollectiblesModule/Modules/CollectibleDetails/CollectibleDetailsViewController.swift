import UIKit
import TKUIKit
import TKCore

class CollectibleDetailsViewController: GenericViewViewController<CollectibleDetailsView> {

  // MARK: - Module

  private let presenter: CollectibleDetailsPresenterInput
  
  // MARK: - ImageLoader
  
  private var imageLoader = ImageLoader()

  // MARK: - Init

  init(presenter: CollectibleDetailsPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
}

// MARK: - CollectibleDetailsViewInput

extension CollectibleDetailsViewController: CollectibleDetailsViewInput {
  func updateTitle(_ title: String?) {
    navigationItem.title = title
  }
  
  func updateView(model: CollectibleDetailsView.Model) {
    customView.configure(model: model)
  }
}

// MARK: - Private

private extension CollectibleDetailsViewController {
  func setup() {
    customView.collectibleView.imageLoader = imageLoader
    setupSwipeDownButton()
    customView.detailsView.didTapOpenInExplorer = { [weak self] in
      self?.presenter.didTapOpenInExplorerButton()
    }
  }
}
