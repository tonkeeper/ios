import KeeperCore
import TKUIKit
import UIKit

extension TokenPickerButton.Configuration {
    static func createConfiguration(token: TonToken) -> Self {
        let title: String
        let image: TKImage
        switch token {
        case .ton:
            title = TonInfo.symbol
            image = .image(.TKCore.Icons.Size44.tonLogo)
        case let .jetton(item):
            title = item.jettonInfo.symbol ?? ""
            image = .urlImage(item.jettonInfo.imageURL)
        }

        return TokenPickerButton.Configuration(
            name: title,
            network: nil,
            image: image
        )
    }
}
