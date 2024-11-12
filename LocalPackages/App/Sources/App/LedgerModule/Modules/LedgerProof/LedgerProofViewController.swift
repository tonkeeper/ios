import UIKit
import TKUIKit
import TKLocalize

final class LedgerProofViewController: GenericViewViewController<LedgerProofView>, TKBottomSheetContentViewController {
  private let viewModel: LedgerProofViewModel
  
  // MARK: - TKBottomSheetContentViewController
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(
      title: .title(
        title: "TKLocales.LedgerProof.title",
        subtitle: nil
      )
    )
  }
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    customView.containerView.systemLayoutSizeFitting(
      CGSize(
        width: width,
        height: 0
      ),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
  }
  
  init(viewModel: LedgerProofViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  deinit {
    viewModel.stopTasks()
  }
}

private extension LedgerProofViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      self?.customView.configure(model: model)
    }
    
    viewModel.showToast = { configuration in
      ToastPresenter.showToast(configuration: configuration)
    }
    
    viewModel.didShowTurnOnBluetoothAlert = { [weak self] in
      self?.showTurnOnBluetoothAlert()
    }
    viewModel.didShowBluetoothAuthorisationAlert = { [weak self] in
      self?.showBluetoothAuthorisationAlert()
    }
  }
  
  func showTurnOnBluetoothAlert() {
    let alertController = UIAlertController(
      title: TKLocales.Bluetooth.PoweredOffAlert.title,
      message: TKLocales.Bluetooth.PoweredOffAlert.message,
      preferredStyle: .alert
    )
    alertController.addAction(UIAlertAction(title: TKLocales.Bluetooth.PoweredOffAlert.openSettings, style: .default, handler: { _ in
      if let url = URL(string: "App-Prefs:root=Bluetooth") {
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
      }
    }))
    alertController.addAction(UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel))
    self.present(alertController, animated: true)
  }
  
  func showBluetoothAuthorisationAlert() {
    let alertController = UIAlertController(
      title: TKLocales.Bluetooth.PermissionsAlert.title,
      message: TKLocales.Bluetooth.PermissionsAlert.message,
      preferredStyle: .alert
    )
    alertController.addAction(UIAlertAction(title: TKLocales.Bluetooth.PermissionsAlert.openSettings, style: .default, handler: { _ in
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
    }))
    alertController.addAction(UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel))
    self.present(alertController, animated: true)
  }
}
