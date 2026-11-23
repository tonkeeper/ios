import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

@MainActor
private final class FundingAssetSheetPreviewController: UIViewController {
    var assetCount = 2
    private var hasPresented = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPresented else { return }
        hasPresented = true
        let assets = (0 ..< assetCount).map { index in
            PerpsFundingAssetRow(
                assetId: "asset-\(index)",
                symbol: index.isMultiple(of: 2) ? "USD₮" : "GRAM",
                network: .ton,
                iconURL: nil,
                balanceText: index.isMultiple(of: 2) ? "3 906 USDT · $3 902" : "2 345 GRAM · $3 456"
            )
        }
        let content = TKBottomSheetScrollHostingController(
            title: TKLocales.Multichain.AssetPicker.chooseTitle,
            subtitle: nil,
            liveSubtitle: nil
        ) {
            PerpsFundingAssetSheetView(assets: assets, selected: assets[0], onSelect: { _ in })
                .tkPreviewTheme(.deepBlue)
        }
        let sheet = TKBottomSheetViewController(contentViewController: content)
        sheet.willPresent = {
            let animationsEnabled = UIView.areAnimationsEnabled
            UIView.setAnimationsEnabled(false)
            DispatchQueue.main.async { UIView.setAnimationsEnabled(animationsEnabled) }
        }
        sheet.present(fromViewController: self)
    }
}

@available(iOS 17.0, *)
#Preview("Two assets") {
    let controller = FundingAssetSheetPreviewController()
    controller.assetCount = 2
    return controller
}

@available(iOS 17.0, *)
#Preview("Long list") {
    let controller = FundingAssetSheetPreviewController()
    controller.assetCount = 16
    return controller
}
