import KeeperCore
import Kingfisher
import SwiftUI
import TKUIKit
import UIKit

enum WalletConnectConfirmationPresenter {
    struct Configuration {
        enum Icon {
            case templateImage(
                image: UIImage,
                tintColor: TKColor,
                size: CGFloat
            )
            case remoteImage(
                url: URL?,
                size: CGFloat,
                cornerRadius: CGFloat
            )
        }

        let title: String
        let caption: String?
        let icon: Icon
        let primaryButtonTitle: String
        let primaryButtonAppearance: ButtonView.Appearance
        let secondaryButtonTitle: String
    }

    static func present(
        configuration: Configuration,
        from viewController: UIViewController,
        primaryAction: @escaping () -> Void
    ) {
        weak var bottomSheetViewController: TKBottomSheetViewController?
        let contentViewController = TKBottomSheetHostingController(
            content: WalletConnectConfirmationView(
                configuration: configuration,
                dismiss: {
                    bottomSheetViewController?.dismiss()
                },
                primaryAction: {
                    bottomSheetViewController?.dismiss(completion: primaryAction)
                }
            ),
            headerConfiguration: .popup
        )
        let sheetViewController = TKBottomSheetViewController(
            contentViewController: contentViewController,
            ignoreBottomSafeArea: true
        )
        bottomSheetViewController = sheetViewController

        sheetViewController.present(fromViewController: viewController)
    }

    static func present(
        validation: WalletConnectValidation,
        from viewController: UIViewController,
        connect: @escaping () -> Void
    ) {
        guard let configuration = Configuration(validation: validation) else {
            connect()
            return
        }

        present(
            configuration: configuration,
            from: viewController,
            primaryAction: connect
        )
    }
}

extension WalletConnectConfirmationPresenter.Configuration {
    static func disconnectDApp(
        appName: String,
        iconURL: URL?,
        disconnectButtonTitle: String,
        cancelButtonTitle: String
    ) -> Self {
        Self(
            title: "Disconnect \(appName)?",
            caption: "This will remove \(appName)’s access to your wallet. You can reconnect it anytime.",
            icon: .remoteImage(
                url: iconURL,
                size: 72,
                cornerRadius: 20
            ),
            primaryButtonTitle: disconnectButtonTitle,
            primaryButtonAppearance: .destructive,
            secondaryButtonTitle: cancelButtonTitle
        )
    }

    static func disconnectAllApps(
        title: String,
        disconnectButtonTitle: String,
        cancelButtonTitle: String
    ) -> Self {
        Self(
            title: title,
            caption: nil,
            icon: .templateImage(
                image: UIImage.TKUIKit.Icons.Size84.exclamationmarkCircle,
                tintColor: .accentRed,
                size: 84
            ),
            primaryButtonTitle: disconnectButtonTitle,
            primaryButtonAppearance: .destructive,
            secondaryButtonTitle: cancelButtonTitle
        )
    }
}

private extension WalletConnectConfirmationPresenter.Configuration {
    init?(validation: WalletConnectValidation) {
        switch validation {
        case .valid:
            return nil
        case .unknown:
            self.init(
                title: "Unknown domain",
                caption: "This domain cannot be verified. Check the request carefully before approving.",
                icon: .templateImage(
                    image: UIImage.TKUIKit.Icons.Size84.exclamationmarkCircle,
                    tintColor: .accentOrange,
                    size: 84
                ),
                primaryButtonTitle: "Connect Wallet",
                primaryButtonAppearance: .attention,
                secondaryButtonTitle: "Cancel"
            )
        case .invalid:
            self.init(
                title: "Domain mismatch",
                caption: "This website has a domain that does not match the sender of this request. Approving may lead to loss of funds.",
                icon: .templateImage(
                    image: UIImage.TKUIKit.Icons.Size28.exclamationmarkTriangle,
                    tintColor: .accentRed,
                    size: 84
                ),
                primaryButtonTitle: "Connect Wallet",
                primaryButtonAppearance: .destructive,
                secondaryButtonTitle: "Cancel"
            )
        case .scam:
            self.init(
                title: "Security risk",
                caption: "This domain is flagged as unsafe by multiple security providers. Leave immediately to protect your assets.",
                icon: .templateImage(
                    image: UIImage.TKUIKit.Icons.Size28.exclamationmarkTriangle,
                    tintColor: .accentRed,
                    size: 84
                ),
                primaryButtonTitle: "Connect Wallet",
                primaryButtonAppearance: .destructive,
                secondaryButtonTitle: "Cancel"
            )
        }
    }
}

private struct WalletConnectConfirmationView: View {
    let configuration: WalletConnectConfirmationPresenter.Configuration
    let dismiss: () -> Void
    let primaryAction: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.iconBottomSpacing) {
                iconView(configuration.icon)

                VStack(spacing: Layout.textSpacing) {
                    Text(configuration.title)
                        .textStyle(.h2)
                        .foregroundStyle(.textPrimary)

                    if let caption = configuration.caption {
                        Text(caption)
                            .textStyle(.body1)
                            .foregroundStyle(.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, Layout.contentTopPadding)
            .padding(.horizontal, Layout.contentHorizontalPadding)
            .padding(.bottom, Layout.contentBottomPadding)

            VStack(spacing: Layout.buttonsSpacing) {
                ButtonView(
                    config: ButtonView.Config(
                        title: configuration.primaryButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: configuration.primaryButtonAppearance,
                        action: primaryAction
                    )
                )

                ButtonView(
                    config: ButtonView.Config(
                        title: configuration.secondaryButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .secondary,
                        action: dismiss
                    )
                )
            }
            .padding(.horizontal, Layout.buttonsHorizontalPadding)
            .padding(.top, Layout.buttonsTopPadding)
            .padding(.bottom, Layout.buttonsBottomPadding)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension WalletConnectConfirmationView {
    @ViewBuilder
    func iconView(_ icon: WalletConnectConfirmationPresenter.Configuration.Icon) -> some View {
        switch icon {
        case let .templateImage(image, tintColor, size):
            SwiftUI.Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tintColor)
                .frame(width: size, height: size)
        case let .remoteImage(url, size, cornerRadius):
            Group {
                if let url {
                    KFImage
                        .url(url)
                        .placeholder {
                            ShimmerSwiftUIView(
                                config: ShimmerSwiftUIView.Config(
                                    color: .backgroundContentTint,
                                    cornerRadius: .value(cornerRadius)
                                )
                            )
                        }
                        .cancelOnDisappear(true)
                        .resizable()
                        .scaledToFill()
                } else {
                    SwiftUI.Image.TKUIKit.Icons.Size44.placeholder
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                }
            }
            .frame(width: size, height: size)
            .background(.backgroundContent)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
        }
    }
}

private extension WalletConnectConfirmationView {
    enum Layout {
        static let contentTopPadding: CGFloat = 8
        static let contentHorizontalPadding: CGFloat = 32
        static let contentBottomPadding: CGFloat = 16
        static let iconBottomSpacing: CGFloat = 21
        static let textSpacing: CGFloat = 3
        static let buttonsHorizontalPadding: CGFloat = 16
        static let buttonsTopPadding: CGFloat = 16
        static let buttonsBottomPadding: CGFloat = 2
        static let buttonsSpacing: CGFloat = 16
    }
}
