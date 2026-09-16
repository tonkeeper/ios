import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

final class PerpsPlaceholderViewController: UIViewController {
    private let featureTitle: String

    init(featureTitle: String) {
        self.featureTitle = featureTitle
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = featureTitle
        view.backgroundColor = .Background.page

        let hostingController = TKHostingController(
            content: PlaceholderView(
                config: PlaceholderView.Config(
                    image: .TKUIKit.Icons.Size28.perps,
                    title: featureTitle,
                    subtitle: TKLocales.Perps.Placeholder.subtitle
                )
            )
        )
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            hostingController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}
