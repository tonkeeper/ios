import KeeperCore
import SwiftUI
import TKUIKit
import UIKit

extension WalletTintColor {
    private struct Variants {
        let light: UIColor
        let dark: UIColor
        let deepBlue: UIColor

        init(light: String, dark: String, deepBlue: String) {
            self.light = UIColor(hex: light)
            self.dark = UIColor(hex: dark)
            self.deepBlue = UIColor(hex: deepBlue)
        }

        init(constant: String) {
            let color = UIColor(hex: constant)
            light = color
            dark = color
            deepBlue = color
        }

        var isConstant: Bool {
            light == dark && light == deepBlue
        }
    }

    private var variants: Variants {
        switch self {
        case .SteelGray:
            Variants(light: "818C99", dark: "2F2F33", deepBlue: "293342")
        case .LightSteelGray:
            Variants(light: "95A0AD", dark: "4E4E52", deepBlue: "424C5C")
        case .Gray:
            Variants(light: "B6BBC2", dark: "8D8D93", deepBlue: "9DA2A4")
        case .LightRed:
            Variants(constant: "FF8585")
        case .LightOrange:
            Variants(constant: "FFA970")
        case .LightYellow:
            Variants(constant: "FFC95C")
        case .LightGreen:
            Variants(constant: "85CC7A")
        case .LightBlue:
            Variants(constant: "70A0FF")
        case .LightAquamarine:
            Variants(constant: "6CCCF5")
        case .LightPurple:
            Variants(constant: "AD89F5")
        case .LightViolet:
            Variants(constant: "F57FF5")
        case .LightMagenta:
            Variants(constant: "F576B1")
        case .LightFireOrange:
            Variants(constant: "F57F87")
        case .Red:
            Variants(constant: "FF5252")
        case .Orange:
            Variants(constant: "FF8B3D")
        case .Yellow:
            Variants(constant: "FFB92E")
        case .Green:
            Variants(constant: "69CC5A")
        case .Blue:
            Variants(constant: "528BFF")
        case .Aquamarine:
            Variants(constant: "47C8FF")
        case .Purple:
            Variants(constant: "925CFF")
        case .Violet:
            Variants(constant: "FF5CFF")
        case .Magenta:
            Variants(constant: "FF479D")
        case .FireOrange:
            Variants(constant: "FF525D")
        }
    }

    var uiColor: UIColor {
        let variants = variants
        guard !variants.isConstant else { return variants.light }
        return UIColor { traitCollection in
            switch TKThemeManager.shared.theme {
            case .deepBlue:
                variants.deepBlue
            case .dark:
                variants.dark
            case .light:
                variants.light
            case .system:
                traitCollection.userInterfaceStyle == .dark ? variants.dark : variants.light
            }
        }
    }

    var themedColor: TKColor {
        let variants = variants
        guard !variants.isConstant else { return .fixed(Color(uiColor: variants.light)) }
        return .perTheme(
            light: Color(uiColor: variants.light),
            dark: Color(uiColor: variants.dark),
            deepBlue: Color(uiColor: variants.deepBlue)
        )
    }
}
