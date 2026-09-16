import KeeperCore
import SwiftUI
import TKUIKit
import UIKit

public extension Wallet {
    func bottomSheetHeaderText(
        palette: TKPalette,
        nameColor: TKColor = .textSecondary,
        iconColor: TKColor = .iconPrimary
    ) -> Text {
        switch icon {
        case let .emoji(emoji):
            return Text("\(emoji) \(label)")
                .foregroundColor(nameColor.resolve(palette))
        case let .icon(icon):
            guard let image = icon.image else {
                return Text(label)
                    .foregroundColor(nameColor.resolve(palette))
            }

            return Text(Image(uiImage: image.withRenderingMode(.alwaysTemplate)))
                .foregroundColor(iconColor.resolve(palette))
                + Text(" \(label)")
                .foregroundColor(nameColor.resolve(palette))
        }
    }
}
