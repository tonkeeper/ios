import SwiftUI

public struct MultichainSwapTokenPickerCapsule: View {
    private let imageSource: AssetAvatarViewImageSource
    private let symbol: String
    private let accessibilityIdentifier: String?
    private let action: () -> Void

    public init(
        imageSource: AssetAvatarViewImageSource,
        symbol: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.imageSource = imageSource
        self.symbol = symbol
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                AssetAvatarView(imageSource: imageSource, size: .extraSmall)
                HStack(spacing: 0) {
                    Text(symbol)
                        .textStyle(.label2)
                        .foregroundStyle(.textPrimary)
                }
                SwiftUI.Image.TKUIKit.Icons.Size16.switch
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.iconSecondary)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(.backgroundContentTint)
            .clipShape(Capsule())
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
