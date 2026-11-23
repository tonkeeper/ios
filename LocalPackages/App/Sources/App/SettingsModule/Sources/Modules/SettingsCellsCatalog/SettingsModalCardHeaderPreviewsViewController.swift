import SwiftUI
import TKUIKit
import UIKit

final class SettingsModalCardHeaderPreviewsViewController: UIViewController {
    private let hostingController = TKHostingController(
        content: CatalogView()
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Background.page

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

/// The catalog shows headers as content, so they stay cards in the Settings stack under liquid glass.
private struct CatalogView: View {
    var body: some View {
        ModalCardHeaderPreviews()
            .tkModalCardHeaderStaysInCard()
    }
}
