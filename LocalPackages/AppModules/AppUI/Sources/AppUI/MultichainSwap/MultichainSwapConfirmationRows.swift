import SwiftUI
import TKUIKit
import UIKit

struct MultichainSwapConfirmationDetailRow: View {
    @Environment(\.tkPalette) private var palette
    let title: String
    let value: String
    var subtitle: String? = nil
    var hintText: String? = nil
    var onTap: ((UIView) -> Void)? = nil
    var valueColor: TKColor = .textPrimary
    var trailingIcon: UIImage? = nil
    var trailingIconColor: TKColor = .iconSecondary
    var trailingAccessory: AnyView? = nil
    var showsDivider = true

    @State private var sourceView: UIView?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                row
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(EdgeInsets(top: 17, leading: 16, bottom: 16, trailing: 16))

            if showsDivider {
                Rectangle()
                    .fill(.separatorCommon)
                    .frame(height: 1 / UIScreen.main.scale)
                    .padding(.leading, 16)
            }
        }
        .background(
            AnchorViewResolver { view in
                if sourceView !== view {
                    sourceView = view
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard let sourceView else { return }
            onTap?(sourceView)
        }
    }

    private var row: some View {
        HStack(spacing: 4) {
            Text(title)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)

            if let hintText {
                HintButton(
                    configuration: HintConfiguration(
                        position: HintPosition(
                            tailParameters: TKHintTextView.tailParameters,
                            horizontal: .default,
                            vertical: .init(absolute: 1),
                            direction: .bottomLeft
                        ),
                        maximumWidth: 200,
                        animationStyle: .bouncing
                    )
                ) { position in
                    TKHintTextView(
                        text: hintText,
                        position: position
                    )
                } label: {
                    SwiftUI.Image.TKUIKit.Icons.Size16.informationCircle
                        .renderingMode(.template)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.iconSecondary)
                }
                .padding([.bottom, .leading], 1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Text(value)
                    .textStyle(.label1)
                    .foregroundColor(valueColor.resolve(palette))
                    .multilineTextAlignment(.trailing)

                if let trailingAccessory {
                    trailingAccessory
                } else if let trailingIcon {
                    SwiftUI.Image(uiImage: trailingIcon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(trailingIconColor.resolve(palette))
                }
            }
        }
    }
}

public struct MultichainSwapConfirmationFeeRow: View {
    @Environment(\.tkPalette) private var palette
    let title: String
    let value: String
    let method: String
    let subtitle: String
    /// The subtitle says what the fee is short of.
    let isShortage: Bool
    let showsDivider: Bool
    let onMethodTap: (() -> Void)?
    /// A tap anywhere on the row, which looks the same with it as without.
    let onTap: (() -> Void)?

    public init(
        title: String,
        value: String,
        method: String = "",
        subtitle: String,
        isShortage: Bool = false,
        showsDivider: Bool = true,
        onMethodTap: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.method = method
        self.subtitle = subtitle
        self.isShortage = isShortage
        self.showsDivider = showsDivider
        self.onMethodTap = onMethodTap
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .center, spacing: 6) {
                    Text(title)
                        .textStyle(.body1)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                        .layoutPriority(2)
                    Spacer(minLength: 8)
                    HStack(spacing: 0) {
                        networkFeeText
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        if let onMethodTap {
                            Button {
                                onMethodTap()
                            } label: {
                                HStack(spacing: 4) {
                                    Text(method)
                                        .textStyle(.label1)
                                        .lineLimit(1)
                                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.switch)
                                }
                                .foregroundStyle(.accentBlue)
                            }
                        } else {
                            Text(method)
                                .textStyle(.label1)
                                .foregroundStyle(.textPrimary)
                                .lineLimit(1)
                        }
                    }
                }

                if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .textStyle(.body2)
                        .foregroundStyle(isShortage ? TKColor.accentRed : TKColor.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)

            if showsDivider {
                Rectangle()
                    .fill(.separatorCommon)
                    .frame(height: 1 / UIScreen.main.scale)
                    .padding(.leading, 16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    var networkFeeText: Text {
        if method.isEmpty {
            return Text(value)
        }
        return Text(value) + Text(" · ").foregroundColor(palette.text.secondary)
    }
}
