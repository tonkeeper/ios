import Foundation

protocol SwapModuleOutput: AnyObject { }

protocol SwapModuleInput: AnyObject { }

protocol SwapViewModel: AnyObject {
  var didUpdateModel: ((SwapView.Model) -> Void)? { get set }
  func viewDidLoad()
}

final class SwapViewModelImplementation: SwapViewModel, SwapModuleOutput, SwapModuleInput {

  // MARK: - SendV3ModuleOutput

  // MARK: - SendV3ModuleInput

  // MARK: - SwapViewModel

  var didUpdateModel: ((SwapView.Model) -> Void)?
  
  func viewDidLoad() { }

  // MARK: - State
  
  // private var recipientInput = ""

  // MARK: - Dependencies
  
  // private let walletsStore: WalletsStore

  init() { }
}

private extension SwapViewModelImplementation { }
