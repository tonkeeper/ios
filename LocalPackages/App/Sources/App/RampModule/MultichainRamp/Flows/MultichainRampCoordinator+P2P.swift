import KeeperCore
import TKCoordinator
import TKLogging
import TKUIKit
import UIKit

extension MultichainRampCoordinator {
    func openP2PExpress(asset: MultichainAsset, currencyCode: String) {
        didTapBuyWithP2P?(wallet)

        let assetDetails = asset.asset

        guard let chain = assetDetails.chain,
              let walletAddress = wallet.multichainAddress(for: chain)
        else {
            Log.multichainRamp.w(
                "p2p express blocked - no wallet address for asset",
                extraInfo: [
                    "assetId": assetDetails.assetId,
                    "chain": assetDetails.chain?.rawValue ?? "unknown",
                ]
            )
            return
        }

        let params = P2PExpressParams(
            wallet: walletAddress,
            assetId: assetDetails.assetId,
            network: nil,
            cryptoCurrency: nil,
            fiatCurrency: currencyCode,
            amount: nil,
            requestNetwork: wallet.network,
            walletId: wallet.multichainWalletId
        )

        let p2pModule = P2PExpressModule(
            dependencies: P2PExpressModule.Dependencies(
                onRampService: keeperCoreMainAssembly.servicesAssembly.onRampService()
            )
        )

        let coordinator = p2pModule.createP2PExpressCoordinator(
            router: ViewControllerRouter(rootViewController: navigationController),
            params: params
        )

        coordinator.didTapOpen = { url, _ in
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        coordinator.didFailToCreateSession = { error in
            Log.multichainRamp.w(
                "p2p express session creation failed",
                error: error,
                extraInfo: ["assetId": assetDetails.assetId, "currency": currencyCode]
            )
            ToastPresenter.showToast(configuration: .init(title: error.localizedDescription))
        }
        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }
}
