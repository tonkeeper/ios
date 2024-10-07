import Foundation
import TKUIKit
import TKCore
import UIKit
import KeeperCore
import TKLocalize

protocol StoriesModuleOutput: AnyObject {
  
}

protocol StoriesViewModel: AnyObject {
  var didUpdateModel: ((StoriesView.Model) -> Void)? { get set }
  
  func safelyIncrementPageIndex()
  func safelyDecrementPageIndex()
  func viewDidLoad()
}

final class StoriesViewModelImplementation: StoriesViewModel, StoriesModuleOutput {
  
  // MARK: - StoriesViewModel
  
  var didUpdateModel: ((StoriesView.Model) -> Void)?
  
  
  func viewDidLoad() {
    storiesController.didUpdateModel = { [weak self] model in
      self?.model = model
    }
    
    storiesController.createModel()
  }
  
  // MARK: - State
  
  private var model: StoriesController.Model? {
    didSet {
      guard let model else { return }
      didUpdateModel?(createModel(model: model, currentPageIndex: currentPageIndex))
    }
  }
  
  private var currentPageIndex: Int = 0 {
    didSet {
      guard let model else { return }
      didUpdateModel?(createModel(model: model, currentPageIndex: currentPageIndex))
    }
  }
  
  func safelyIncrementPageIndex() {
    guard let model else { return }
    currentPageIndex = min(currentPageIndex + 1, model.pages.count - 1)
  }
  
  func safelyDecrementPageIndex() {
    guard model != nil else { return }
    currentPageIndex = max(currentPageIndex - 1, 0)
  }

  // MARK: - Dependencies
  
  private let storiesController: StoriesController
  
  init(storiesController: StoriesController) {
    self.storiesController = storiesController
  }
}

private extension StoriesViewModelImplementation {
  func createModel(model: KeeperCore.StoriesController.Model, currentPageIndex: Int) -> StoriesView.Model {
    return StoriesView.Model(currentPageIndex: currentPageIndex, pages: model.pages)
  }
}
