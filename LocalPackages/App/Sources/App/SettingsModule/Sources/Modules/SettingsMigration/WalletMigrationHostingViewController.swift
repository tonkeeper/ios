import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

final class WalletMigrationHostingViewController: UIViewController {
    var isInteractivePopDisabled = false
    var showsNavigationBar = false

    private var previousInteractivePopEnabled: Bool?
    private let hostingController: TKHostingController<WalletMigrationScreen>

    init(viewModel: WalletMigrationViewModel) {
        self.hostingController = TKHostingController(
            content: WalletMigrationScreen(viewModel: viewModel)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if showsNavigationBar {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
        if isInteractivePopDisabled, let popGesture = navigationController?.interactivePopGestureRecognizer {
            if previousInteractivePopEnabled == nil {
                previousInteractivePopEnabled = popGesture.isEnabled
            }
            popGesture.isEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if showsNavigationBar, isMovingFromParent {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
        if isInteractivePopDisabled,
           let previousInteractivePopEnabled,
           let popGesture = navigationController?.interactivePopGestureRecognizer
        {
            popGesture.isEnabled = previousInteractivePopEnabled
            self.previousInteractivePopEnabled = nil
        }
    }

    func setupSkipButton(_ action: @escaping () -> Void) {
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = nil
        let button = TKUIHeaderTitleIconButton()
        button.configure(
            model: TKUIButtonTitleIconContentView.Model(
                title: TKLocales.Onboarding.BackupIntro.later
            )
        )
        button.addTapAction(action)
        button.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }
}
