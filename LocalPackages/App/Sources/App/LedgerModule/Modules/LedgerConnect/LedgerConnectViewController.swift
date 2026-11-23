import TKLocalize
import TKUIKit
import UIKit

final class LedgerConnectViewController: GenericViewViewController<LedgerConnectView>, TKBottomSheetContentViewController {
    private let viewModel: LedgerConnectViewModel

    // MARK: - TKBottomSheetContentViewController

    var didUpdateHeight: (() -> Void)?

    var headerConfiguration: TKBottomSheetHeaderConfiguration? {
        TKBottomSheetHeaderConfiguration(
            title: .title(title: TKLocales.LedgerConnect.title)
        )
    }

    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

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

    init(viewModel: LedgerConnectViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
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

private extension LedgerConnectViewController {
    func setupBindings() {
        viewModel.didUpdateModel = { [weak self] model in
            self?.customView.configure(model: model)
            self?.didUpdateHeight?()
        }

        viewModel.didShowTurnOnBluetoothAlert = { [weak self] in
            self?.showTurnOnBluetoothAlert()
        }
        viewModel.didShowBluetoothAuthorisationAlert = { [weak self] in
            self?.showBluetoothAuthorisationAlert()
        }
        viewModel.didShowPairingRemovedAlert = { [weak self] retry in
            self?.showPairingRemovedAlert(retry: retry)
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

    func showPairingRemovedAlert(retry: @escaping () -> Void) {
        let alertController = UIAlertController(
            title: TKLocales.Bluetooth.PairingRemovedAlert.title,
            message: TKLocales.Bluetooth.PairingRemovedAlert.message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: TKLocales.Actions.ok, style: .default, handler: { _ in
            retry()
        }))
        self.present(alertController, animated: true)
    }
}
