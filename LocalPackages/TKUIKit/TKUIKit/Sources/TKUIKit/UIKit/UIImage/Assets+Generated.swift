// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ColorAsset.Color", message: "This typealias will be removed in SwiftGen 7.0")
public typealias AssetColorTypeAlias = ColorAsset.Color
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
public typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
public enum Assets {
  public enum Colors {
    public enum Accent {
      public static let blue = ColorAsset(name: "Colors/Accent/Blue")
      public static let green = ColorAsset(name: "Colors/Accent/Green")
      public static let orange = ColorAsset(name: "Colors/Accent/Orange")
      public static let purple = ColorAsset(name: "Colors/Accent/Purple")
      public static let red = ColorAsset(name: "Colors/Accent/Red")
    }
    public enum Background {
      public static let contentAttention = ColorAsset(name: "Colors/Background/Content Attention")
      public static let contentTint = ColorAsset(name: "Colors/Background/Content Tint")
      public static let content = ColorAsset(name: "Colors/Background/Content")
      public static let highlighted = ColorAsset(name: "Colors/Background/Highlighted")
      public static let overlayExtraLight = ColorAsset(name: "Colors/Background/Overlay Extra Light")
      public static let overlayLight = ColorAsset(name: "Colors/Background/Overlay Light")
      public static let overlayStrong = ColorAsset(name: "Colors/Background/Overlay Strong")
      public static let page = ColorAsset(name: "Colors/Background/Page")
      public static let transparent = ColorAsset(name: "Colors/Background/Transparent")
    }
    public enum Button {
      public static let primaryBackgroundDisabled = ColorAsset(name: "Colors/Button/Primary Background Disabled")
      public static let primaryBackgroundHighlighted = ColorAsset(name: "Colors/Button/Primary Background Highlighted")
      public static let primaryBackground = ColorAsset(name: "Colors/Button/Primary Background")
      public static let primaryForeground = ColorAsset(name: "Colors/Button/Primary Foreground")
      public static let secondaryBackgroundDisabled = ColorAsset(name: "Colors/Button/Secondary Background Disabled")
      public static let secondaryBackgroundHighlighted = ColorAsset(name: "Colors/Button/Secondary Background Highlighted")
      public static let secondaryBackground = ColorAsset(name: "Colors/Button/Secondary Background")
      public static let secondaryForeground = ColorAsset(name: "Colors/Button/Secondary Foreground")
      public static let tertiaryBackgroundDisabled = ColorAsset(name: "Colors/Button/Tertiary Background Disabled")
      public static let tertiaryBackgroundHighlighted = ColorAsset(name: "Colors/Button/Tertiary Background Highlighted")
      public static let tertiaryBackground = ColorAsset(name: "Colors/Button/Tertiary Background")
      public static let tertiaryForeground = ColorAsset(name: "Colors/Button/Tertiary Foreground")
    }
    public enum ConstantSystem {
      public static let tonBlue = ColorAsset(name: "Colors/Constant&System/TON Blue")
    }
    public enum Field {
      public static let activeBorder = ColorAsset(name: "Colors/Field/Active Border")
      public static let background = ColorAsset(name: "Colors/Field/Background")
      public static let errorBackground = ColorAsset(name: "Colors/Field/Error Background")
      public static let errorBorder = ColorAsset(name: "Colors/Field/Error Border")
    }
    public enum Icon {
      public static let primaryAlternate = ColorAsset(name: "Colors/Icon/Primary Alternate")
      public static let primary = ColorAsset(name: "Colors/Icon/Primary")
      public static let secondary = ColorAsset(name: "Colors/Icon/Secondary")
      public static let tertiary = ColorAsset(name: "Colors/Icon/Tertiary")
    }
    public enum Separator {
      public static let alternate = ColorAsset(name: "Colors/Separator/Alternate")
      public static let common = ColorAsset(name: "Colors/Separator/Common")
    }
    public enum TabBar {
      public static let activeIcon = ColorAsset(name: "Colors/TabBar/Active Icon")
      public static let inactiveIcon = ColorAsset(name: "Colors/TabBar/Inactive Icon")
    }
    public enum Text {
      public static let accent = ColorAsset(name: "Colors/Text/Accent")
      public static let primaryAlternate = ColorAsset(name: "Colors/Text/Primary Alternate")
      public static let primary = ColorAsset(name: "Colors/Text/Primary")
      public static let secondary = ColorAsset(name: "Colors/Text/Secondary")
      public static let tertiary = ColorAsset(name: "Colors/Text/Tertiary")
    }
  }
  public enum Icons {
    public enum _12 {
      public static let icChevronRight12 = ImageAsset(name: "Icons/12/ic-chevron-right-12")
      public static let icInformationCircle12 = ImageAsset(name: "Icons/12/ic-information-circle-12")
      public static let icLock12 = ImageAsset(name: "Icons/12/ic-lock-12")
      public static let icPin12 = ImageAsset(name: "Icons/12/ic-pin-12")
    }
    public enum _16 {
      public static let icChevronDown16 = ImageAsset(name: "Icons/16/ic-chevron-down-16")
      public static let icChevronLeft16 = ImageAsset(name: "Icons/16/ic-chevron-left-16")
      public static let icChevronRight16 = ImageAsset(name: "Icons/16/ic-chevron-right-16")
      public static let icClose16 = ImageAsset(name: "Icons/16/ic-close-16")
      public static let icCopy16 = ImageAsset(name: "Icons/16/ic-copy-16")
      public static let icDone16 = ImageAsset(name: "Icons/16/ic-done-16")
      public static let icDoneBold16 = ImageAsset(name: "Icons/16/ic-done-bold-16")
      public static let icDote16 = ImageAsset(name: "Icons/16/ic-dote-16")
      public static let icEllipsis16 = ImageAsset(name: "Icons/16/ic-ellipsis-16")
      public static let icGlobe16 = ImageAsset(name: "Icons/16/ic-globe-16")
      public static let icInformationCircle16 = ImageAsset(name: "Icons/16/ic-information-circle-16")
      public static let icMagnifyingGlass16 = ImageAsset(name: "Icons/16/ic-magnifying-glass-16")
      public static let icMinus16 = ImageAsset(name: "Icons/16/ic-minus-16")
      public static let icPlus16 = ImageAsset(name: "Icons/16/ic-plus-16")
      public static let icQrCode16 = ImageAsset(name: "Icons/16/ic-qr-code-16")
      public static let icSaleBadge16 = ImageAsset(name: "Icons/16/ic-sale-badge-16")
      public static let icShare16 = ImageAsset(name: "Icons/16/ic-share-16")
      public static let icSwapVertical16 = ImageAsset(name: "Icons/16/ic-swap-vertical-16")
      public static let icSwitch16 = ImageAsset(name: "Icons/16/ic-switch-16")
      public static let icTelegram16 = ImageAsset(name: "Icons/16/ic-telegram-16")
      public static let icTwitter16 = ImageAsset(name: "Icons/16/ic-twitter-16")
      public static let icVerification16Gray = ImageAsset(name: "Icons/16/ic-verification-16-gray")
      public static let icVerification16 = ImageAsset(name: "Icons/16/ic-verification-16")
      public static let icXmarkCircle16 = ImageAsset(name: "Icons/16/ic-xmark-circle-16")
    }
    public enum _28 {
      public static let icArrowDownOutline28 = ImageAsset(name: "Icons/28/ic-arrow-down-outline-28")
      public static let icArrowRightOutline28 = ImageAsset(name: "Icons/28/ic-arrow-right-outline-28")
      public static let icArrowUpOutline28 = ImageAsset(name: "Icons/28/ic-arrow-up-outline-28")
      public static let icBell28 = ImageAsset(name: "Icons/28/ic-bell-28")
      public static let icClock28 = ImageAsset(name: "Icons/28/ic-clock-28")
      public static let icCopy28 = ImageAsset(name: "Icons/28/ic-copy-28")
      public static let icDoc28 = ImageAsset(name: "Icons/28/ic-doc-28")
      public static let icDonemarkOtline28 = ImageAsset(name: "Icons/28/ic-donemark-otline-28")
      public static let icDoor28 = ImageAsset(name: "Icons/28/ic-door-28")
      public static let icExclamationmarkTriangle28 = ImageAsset(name: "Icons/28/ic-exclamationmark-triangle-28")
      public static let icExplore28 = ImageAsset(name: "Icons/28/ic-explore-28")
      public static let icEyeClosedOutline28 = ImageAsset(name: "Icons/28/ic-eye-closed-outline-28")
      public static let icEyeOutline28 = ImageAsset(name: "Icons/28/ic-eye-outline-28")
      public static let icFaceid28 = ImageAsset(name: "Icons/28/ic-faceid-28")
      public static let icGear28 = ImageAsset(name: "Icons/28/ic-gear-28")
      public static let icGearOutline28 = ImageAsset(name: "Icons/28/ic-gear-outline-28")
      public static let icGlobe28 = ImageAsset(name: "Icons/28/ic-globe-28")
      public static let icKey28 = ImageAsset(name: "Icons/28/ic-key-28")
      public static let icLedger28 = ImageAsset(name: "Icons/28/ic-ledger-28")
      public static let icLinkOutline28 = ImageAsset(name: "Icons/28/ic-link-outline-28")
      public static let icLock28 = ImageAsset(name: "Icons/28/ic-lock-28")
      public static let icMagnifyingGlass28 = ImageAsset(name: "Icons/28/ic-magnifying-glass-28")
      public static let icMessageBubble28 = ImageAsset(name: "Icons/28/ic-message-bubble-28")
      public static let icMinus28 = ImageAsset(name: "Icons/28/ic-minus-28")
      public static let icMinusOutline28 = ImageAsset(name: "Icons/28/ic-minus-outline-28")
      public static let icNotification28 = ImageAsset(name: "Icons/28/ic-notification-28")
      public static let icPencil28 = ImageAsset(name: "Icons/28/ic-pencil-28")
      public static let icPencilOutline28 = ImageAsset(name: "Icons/28/ic-pencil-outline-28")
      public static let icPin28 = ImageAsset(name: "Icons/28/ic-pin-28")
      public static let icPlus28 = ImageAsset(name: "Icons/28/ic-plus-28")
      public static let icPlusCircle28 = ImageAsset(name: "Icons/28/ic-plus-circle-28")
      public static let icPlusOutline28 = ImageAsset(name: "Icons/28/ic-plus-outline-28")
      public static let icPlusThin28 = ImageAsset(name: "Icons/28/ic-plus-thin-28")
      public static let icPurchases28 = ImageAsset(name: "Icons/28/ic-purchases-28")
      public static let icQrViewfinder28 = ImageAsset(name: "Icons/28/ic-qr-viewfinder-28")
      public static let icQrViewfinderThin28 = ImageAsset(name: "Icons/28/ic-qr-viewfinder-thin-28")
      public static let icQuestion28 = ImageAsset(name: "Icons/28/ic-question-28")
      public static let icReorder28 = ImageAsset(name: "Icons/28/ic-reorder-28")
      public static let icSigner28 = ImageAsset(name: "Icons/28/ic-signer-28")
      public static let icStakingOutline28 = ImageAsset(name: "Icons/28/ic-staking-outline-28")
      public static let icStar28 = ImageAsset(name: "Icons/28/ic-star-28")
      public static let icSwapHorizontalOutline28 = ImageAsset(name: "Icons/28/ic-swap-horizontal-outline-28")
      public static let icTelegram28 = ImageAsset(name: "Icons/28/ic-telegram-28")
      public static let icTestnet28 = ImageAsset(name: "Icons/28/ic-testnet-28")
      public static let icTrashBin28 = ImageAsset(name: "Icons/28/ic-trash-bin-28")
      public static let icUsd28 = ImageAsset(name: "Icons/28/ic-usd-28")
      public static let icWallet28 = ImageAsset(name: "Icons/28/ic-wallet-28")
    }
    public enum _32 {
      public static let icCheckmarkCircle32 = ImageAsset(name: "Icons/32/ic-checkmark-circle-32")
      public static let icExclamationmarkCircle32 = ImageAsset(name: "Icons/32/ic-exclamationmark-circle-32")
    }
    public enum _36 {
      public static let icDelete36 = ImageAsset(name: "Icons/36/ic-delete-36")
      public static let icFaceid36 = ImageAsset(name: "Icons/36/ic-faceid-36")
      public static let icFingerprint36 = ImageAsset(name: "Icons/36/ic-fingerprint-36")
    }
    public enum _44 {
      public static let icTonnominators44 = ImageAsset(name: "Icons/44/ic-tonnominators-44")
      public static let icTonstakers44 = ImageAsset(name: "Icons/44/ic-tonstakers-44")
      public static let icTonwhales44 = ImageAsset(name: "Icons/44/ic-tonwhales-44")
      public static let tonCurrency = ImageAsset(name: "Icons/44/ton_currency")
    }
    public enum _56 {
      public static let icFlashlightOff56 = ImageAsset(name: "Icons/56/ic-flashlight-off-56")
    }
    public enum _84 {
      public static let icCamera84 = ImageAsset(name: "Icons/84/ic-camera-84")
      public static let icExclamationmarkCircle84 = ImageAsset(name: "Icons/84/ic-exclamationmark-circle-84")
    }
    public enum _96 {
      public static let tonIcon = ImageAsset(name: "Icons/96/ton_icon")
    }
    public enum WalletIcons {
      public static let bankCard16 = ImageAsset(name: "Icons/WalletIcons/bank-card-16")
      public static let chineseYuanCircle16 = ImageAsset(name: "Icons/WalletIcons/chinese-yuan-circle-16")
      public static let dollarCircle16 = ImageAsset(name: "Icons/WalletIcons/dollar-circle-16")
      public static let euroCircle16 = ImageAsset(name: "Icons/WalletIcons/euro-circle-16")
      public static let flash16 = ImageAsset(name: "Icons/WalletIcons/flash-16")
      public static let flashCircle16 = ImageAsset(name: "Icons/WalletIcons/flash-circle-16")
      public static let gear16 = ImageAsset(name: "Icons/WalletIcons/gear-16")
      public static let handRaised16 = ImageAsset(name: "Icons/WalletIcons/hand-raised-16")
      public static let hare16 = ImageAsset(name: "Icons/WalletIcons/hare-16")
      public static let inbox16 = ImageAsset(name: "Icons/WalletIcons/inbox-16")
      public static let indianRupeeCircle16 = ImageAsset(name: "Icons/WalletIcons/indian-rupee-circle-16")
      public static let key16 = ImageAsset(name: "Icons/WalletIcons/key-16")
      public static let leaf16 = ImageAsset(name: "Icons/WalletIcons/leaf-16")
      public static let lock16 = ImageAsset(name: "Icons/WalletIcons/lock-16")
      public static let magnifyingGlassCircle16 = ImageAsset(name: "Icons/WalletIcons/magnifying-glass-circle-16")
      public static let rubleCircle16 = ImageAsset(name: "Icons/WalletIcons/ruble-circle-16")
      public static let snowflake16 = ImageAsset(name: "Icons/WalletIcons/snowflake-16")
      public static let sparkles16 = ImageAsset(name: "Icons/WalletIcons/sparkles-16")
      public static let sterlingCircle16 = ImageAsset(name: "Icons/WalletIcons/sterling-circle-16")
      public static let sun16 = ImageAsset(name: "Icons/WalletIcons/sun-16")
      public static let wallet16 = ImageAsset(name: "Icons/WalletIcons/wallet-16")
    }
  }
  public enum Images {
    public static let textSpoiler = ImageAsset(name: "Images/text_spoiler")
    public static let tonkeeperLogo = ImageAsset(name: "Images/tonkeeper_logo")
  }
  public static let rectangle = ImageAsset(name: "Rectangle")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

public final class ColorAsset {
  public fileprivate(set) var name: String

  #if os(macOS)
  public typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  public typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  public private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  #if os(iOS) || os(tvOS)
  @available(iOS 11.0, tvOS 11.0, *)
  public func color(compatibleWith traitCollection: UITraitCollection) -> Color {
    let bundle = BundleToken.bundle
    guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  public private(set) lazy var swiftUIColor: SwiftUI.Color = {
    SwiftUI.Color(asset: self)
  }()
  #endif

  fileprivate init(name: String) {
    self.name = name
  }
}

public extension ColorAsset.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  convenience init?(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public extension SwiftUI.Color {
  init(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }
}
#endif

public struct ImageAsset {
  public fileprivate(set) var name: String

  #if os(macOS)
  public typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  public typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  public var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  public func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  public var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

public extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public extension SwiftUI.Image {
  init(asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: ImageAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
