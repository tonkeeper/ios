import SwiftUI
import TKUIKit
import UIKit

final class SettingsTransactionCellPreviewsViewController: UIViewController {
    private let hostingController = TKHostingController(
        content: TransactionCellPreviews()
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
