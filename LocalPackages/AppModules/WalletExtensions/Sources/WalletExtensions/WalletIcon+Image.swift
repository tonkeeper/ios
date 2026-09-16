import KeeperCore
import SwiftUI
import TKUIKit
import UIKit

public extension WalletIcon.Image {
    /// Unlike `image`, keeps the vector representation of the PDF assets, so it
    /// stays sharp when rendered above the 16pt nominal size.
    var swiftUIImage: SwiftUI.Image {
        switch self {
        case .wallet:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarWallet
        case .leaf:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarLeaf
        case .lock:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarLock
        case .key:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarKey
        case .inbox:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarInbox
        case .snowflake:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarSnowflake
        case .sparkles:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarSparkles
        case .sun:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarSun
        case .hare:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarHare
        case .flash:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarFlash
        case .bankCard:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarBankCard
        case .gear:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarGear
        case .handRaised:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarHandRaised
        case .magnifyingGlassCircle:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarMagnifyingGlassCircle
        case .flashCircle:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarFlashCircle
        case .dollarCircle:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarDollarCircle
        case .euroCircle:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarEuroCircle
        case .sterlingCircle:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarSterlingCircle
        case .yuanCircle:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarChineseYuanCircle
        case .rubleCircle:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarRubleCircle
        case .indianRupeeCircle:
            SwiftUI.Image.TKUIKit.Icons.Size16.walletAvatarIndianRupeeCircle
        }
    }

    var image: UIImage? {
        switch self {
        case .wallet:
            return .TKUIKit.Icons.Size16.walletAvatarWallet
        case .leaf:
            return .TKUIKit.Icons.Size16.walletAvatarLeaf
        case .lock:
            return .TKUIKit.Icons.Size16.walletAvatarLock
        case .key:
            return .TKUIKit.Icons.Size16.walletAvatarKey
        case .inbox:
            return .TKUIKit.Icons.Size16.walletAvatarInbox
        case .snowflake:
            return .TKUIKit.Icons.Size16.walletAvatarSnowflake
        case .sparkles:
            return .TKUIKit.Icons.Size16.walletAvatarSparkles
        case .sun:
            return .TKUIKit.Icons.Size16.walletAvatarSun
        case .hare:
            return .TKUIKit.Icons.Size16.walletAvatarHare
        case .flash:
            return .TKUIKit.Icons.Size16.walletAvatarFlash
        case .bankCard:
            return .TKUIKit.Icons.Size16.walletAvatarBankCard
        case .gear:
            return .TKUIKit.Icons.Size16.walletAvatarGear
        case .handRaised:
            return .TKUIKit.Icons.Size16.walletAvatarHandRaised
        case .magnifyingGlassCircle:
            return .TKUIKit.Icons.Size16.walletAvatarMagnifyingGlassCircle
        case .flashCircle:
            return .TKUIKit.Icons.Size16.walletAvatarFlashCircle
        case .dollarCircle:
            return .TKUIKit.Icons.Size16.walletAvatarDollarCircle
        case .euroCircle:
            return .TKUIKit.Icons.Size16.walletAvatarEuroCircle
        case .sterlingCircle:
            return .TKUIKit.Icons.Size16.walletAvatarSterlingCircle
        case .yuanCircle:
            return .TKUIKit.Icons.Size16.walletAvatarChineseYuanCircle
        case .rubleCircle:
            return .TKUIKit.Icons.Size16.walletAvatarRubleCircle
        case .indianRupeeCircle:
            return .TKUIKit.Icons.Size16.walletAvatarIndianRupeeCircle
        }
    }
}
