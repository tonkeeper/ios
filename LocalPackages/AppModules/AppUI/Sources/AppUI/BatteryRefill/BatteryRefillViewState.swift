import Foundation
import TKUIKit
import UIKit

public struct BatteryRefillViewState {
    public struct Header {
        public let batteryState: BatterySwiftUIViewConfig.State
        public let charges: String?
        public let description: String
        public let warning: String?

        public init(
            batteryState: BatterySwiftUIViewConfig.State,
            charges: String?,
            description: String,
            warning: String?
        ) {
            self.batteryState = batteryState
            self.charges = charges
            self.description = description
            self.warning = warning
        }
    }

    public struct Pack: Identifiable {
        public enum Icon {
            case fill(CGFloat)
            case other
        }

        public let id: String
        public let title: String
        public let caption: String
        public let icon: Icon
        public let tag: String?
        public let isEnabled: Bool
        public let isSelected: Bool

        public init(
            id: String,
            title: String,
            caption: String,
            icon: Icon,
            tag: String? = nil,
            isEnabled: Bool = true,
            isSelected: Bool = false
        ) {
            self.id = id
            self.title = title
            self.caption = caption
            self.icon = icon
            self.tag = tag
            self.isEnabled = isEnabled
            self.isSelected = isSelected
        }
    }

    public struct PaymentMethod: Identifiable {
        public enum Icon {
            case asset(AssetAvatarViewImageSource)
            case appStore
            case ton
            case url(URL?)
        }

        /// A token listed under Other tokens instead of the Pay with list itself.
        public struct OtherToken {
            public let chain: Chain
            public let row: AssetBalanceRowCellContent

            public init(chain: Chain, row: AssetBalanceRowCellContent) {
                self.chain = chain
                self.row = row
            }
        }

        public struct Chain {
            public let id: String
            public let title: String
            public let image: UIImage?

            public init(id: String, title: String, image: UIImage?) {
                self.id = id
                self.title = title
                self.image = image
            }
        }

        public let id: String
        public let icon: Icon
        public let name: String
        public let caption: String
        public let isSelected: Bool
        public let otherToken: OtherToken?

        public init(id: String, icon: Icon, name: String, caption: String, isSelected: Bool = false, otherToken: OtherToken? = nil) {
            self.id = id
            self.icon = icon
            self.name = name
            self.caption = caption
            self.isSelected = isSelected
            self.otherToken = otherToken
        }
    }

    public enum Link: String, Identifiable {
        case gift
        case history

        public var id: String {
            rawValue
        }
    }

    public struct MainButton {
        public let title: String
        public let isEnabled: Bool
        public let isLoading: Bool

        public init(title: String, isEnabled: Bool, isLoading: Bool = false) {
            self.title = title
            self.isEnabled = isEnabled
            self.isLoading = isLoading
        }
    }

    public var header: Header?
    public var showsTronBanner: Bool
    public var packs: [Pack]
    public var showsAmount: Bool
    public var paymentMethod: PaymentMethod?
    public var paymentCaption: String?
    public var links: [Link]
    public var showsPromocode: Bool
    public var footer: String
    public var mainButton: MainButton?
    public var showsCloseButton: Bool

    public init(
        header: Header? = nil,
        showsTronBanner: Bool = false,
        packs: [Pack] = [],
        showsAmount: Bool = false,
        paymentMethod: PaymentMethod? = nil,
        paymentCaption: String? = nil,
        links: [Link] = [],
        showsPromocode: Bool = false,
        footer: String = "",
        mainButton: MainButton? = nil,
        showsCloseButton: Bool = false
    ) {
        self.header = header
        self.showsTronBanner = showsTronBanner
        self.packs = packs
        self.showsAmount = showsAmount
        self.paymentMethod = paymentMethod
        self.paymentCaption = paymentCaption
        self.links = links
        self.showsPromocode = showsPromocode
        self.footer = footer
        self.mainButton = mainButton
        self.showsCloseButton = showsCloseButton
    }
}

public struct BatteryRefillViewActions {
    public let selectPack: (String) -> Void
    public let choosePaymentMethod: () -> Void
    public let confirm: () -> Void
    public let openLink: (BatteryRefillViewState.Link) -> Void
    public let openSupportedTransactions: () -> Void
    public let restorePurchases: () -> Void
    public let close: () -> Void
    public let endEditing: () -> Void

    public init(
        selectPack: @escaping (String) -> Void,
        choosePaymentMethod: @escaping () -> Void,
        confirm: @escaping () -> Void,
        openLink: @escaping (BatteryRefillViewState.Link) -> Void,
        openSupportedTransactions: @escaping () -> Void,
        restorePurchases: @escaping () -> Void,
        close: @escaping () -> Void,
        endEditing: @escaping () -> Void
    ) {
        self.selectPack = selectPack
        self.choosePaymentMethod = choosePaymentMethod
        self.confirm = confirm
        self.openLink = openLink
        self.openSupportedTransactions = openSupportedTransactions
        self.restorePurchases = restorePurchases
        self.close = close
        self.endEditing = endEditing
    }
}
