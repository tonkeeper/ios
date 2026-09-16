import SwiftUI
import TKUIKit

struct ReceiveQRCardView: View {
    private let matrix: QrCodeMatrix?
    private let address: String
    private let avatarImageSource: AssetAvatarViewImageSource
    private let tag: TKTagSwiftUIViewConfig?
    private let onCopy: () -> Void

    init(
        matrix: QrCodeMatrix?,
        network: ReceiveNetworkViewData,
        onCopy: @escaping () -> Void
    ) {
        self.matrix = matrix
        self.address = network.address
        self.avatarImageSource = network.avatarImageSource
        self.tag = nil
        self.onCopy = onCopy
    }

    init(
        matrix: QrCodeMatrix?,
        address: String?,
        avatarImageSource: AssetAvatarViewImageSource,
        tag: TKTagSwiftUIViewConfig?,
        onCopy: @escaping () -> Void
    ) {
        self.matrix = matrix
        self.address = address ?? ""
        self.avatarImageSource = avatarImageSource
        self.tag = tag
        self.onCopy = onCopy
    }

    var body: some View {
        VStack(spacing: -1) {
            ReceiveQRCodeImageView(
                matrix: matrix,
                avatarImageSource: avatarImageSource
            )
            .padding(.horizontal, 12)

            Button(action: onCopy) {
                Text(address.multilineReceiveAddress)
                    .textStyle(.body1Mono)
                    .foregroundStyle(Color.black)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }

            if let tag {
                TKTagSwiftUIView(config: tag)
                    .padding(.top, 10)
            }
        }
        .padding(.top, 13)
        .padding(.bottom, tag == nil ? 24 : 22)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ReceiveQRCodeImageView: View {
    let matrix: QrCodeMatrix?
    let avatarImageSource: AssetAvatarViewImageSource

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)

            if let matrix {
                QrCodeView(
                    matrix: matrix,
                    configuration: QrCodeGeneratorConfiguration(
                        centerCutoutSize: Layout.centerCutoutSize
                    )
                ) {
                    centerAvatar
                }
            } else {
                CircularLoader(
                    mode: .indeterminate,
                    preset: .medium
                )
                centerAvatar
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var centerAvatar: some View {
        AssetAvatarView(
            imageSource: avatarImageSource,
            size: .regular
        )
        .background(Color.white)
    }

    private enum Layout {
        static let centerCutoutSize = CGSize(width: 72, height: 72)
    }
}
