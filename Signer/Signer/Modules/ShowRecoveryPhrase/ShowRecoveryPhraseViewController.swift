//import UIKit
//import TKUIKit
//import TKScreenKit
//
//final class ShowRecoveryPhraseViewController: UIViewController {
//  private let viewModel: ShowRecoveryPhraseViewModel
//  
//  private let recoveryPhraseViewController = TKRecoveryPhraseViewController()
//  
//  init(viewModel: ShowRecoveryPhraseViewModel) {
//    self.viewModel = viewModel
//    super.init(nibName: nil, bundle: nil)
//  }
//  
//  required init?(coder: NSCoder) {
//    fatalError("init(coder:) has not been implemented")
//  }
//  
//  override func viewDidLoad() {
//    super.viewDidLoad()
//    setup()
//    setupBindings()
//    viewModel.viewDidLoad()
//  }
//}
//
//private extension ShowRecoveryPhraseViewController {
//  func setup() {
//    addChild(recoveryPhraseViewController)
//    view.addSubview(recoveryPhraseViewController.view)
//    recoveryPhraseViewController.didMove(toParent: self)
//    
//    recoveryPhraseViewController.didTapCopy = { [weak self] in
//      ToastPresenter.showToast(configuration: .copied)
//      self?.viewModel.didTapCopyButton()
//    }
//    
//    setupConstraints()
//  }
//  
//  func setupConstraints() {
//    recoveryPhraseViewController.view.translatesAutoresizingMaskIntoConstraints = false
//    
//    NSLayoutConstraint.activate([
//      recoveryPhraseViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
//      recoveryPhraseViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
//      recoveryPhraseViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//      recoveryPhraseViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor)
//    ])
//  }
//  
//  func setupBindings() {
//    viewModel.didUpdateModel = { [recoveryPhraseViewController] model in
//      recoveryPhraseViewController.configure(with: model)
//    }
//  }
//}
