import UIKit
import TKUIKit

final class StoriesViewController: GenericViewViewController<StoriesView> {
  private let viewModel: StoriesViewModel
  
  init(viewModel: StoriesViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @objc
  func handleTap(_ gesture: UITapGestureRecognizer) {
    let tapLocation = gesture.location(in: self.view)
    let screenWidth = self.view.bounds.width
    
    if tapLocation.x < screenWidth / 2 {
      viewModel.safelyDecrementPageIndex()
    } else {
      viewModel.safelyIncrementPageIndex()
    }
  }
  
  func addTapGestureRecognizers() {
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
    self.view.addGestureRecognizer(tapGestureRecognizer)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
    addTapGestureRecognizers()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
  }
}

private extension StoriesViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
  }
}
