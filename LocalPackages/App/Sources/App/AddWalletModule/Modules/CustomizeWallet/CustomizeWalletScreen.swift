import KeeperCore
import SwiftUI
import TKUIKit
import UIKit
import WalletExtensions

struct CustomizeWalletScreen: View {
    @ObservedObject var viewModel: CustomizeWalletViewModel

    @FocusState private var isNameFieldFocused: Bool
    @State private var continueBarHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(config: headerConfig)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    titleView
                        .allowsHitTesting(false)
                    nameField
                    colorPicker
                        .pickerDimmed(isNameFieldFocused)
                    iconPicker
                        .pickerDimmed(isNameFieldFocused)
                }
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isNameFieldFocused = false
                        }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)

                if viewModel.continueButtonTitle != nil {
                    continueButton
                } else {
                    Color.clear
                        .frame(height: Layout.iconGridTopScrimHeight)
                        .ignoresSafeArea(.container, edges: .bottom)
                        .tkScrim(.backgroundPage, edge: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .onPreferenceChange(ContinueBarHeightKey.self) { continueBarHeight = $0 }
        .task {
            await viewModel.start()
        }
    }
}

private struct ContinueBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension CustomizeWalletScreen {
    var headerConfig: DefaultModalCardHeader.Config {
        DefaultModalCardHeader.Config(
            leftIcon: viewModel.leftHeaderButton.map(headerIcon),
            rightIcon: viewModel.rightHeaderButton.map(headerIcon),
            height: .compact
        )
    }

    func headerIcon(_ button: CustomizeWalletViewModel.HeaderButton) -> DefaultModalCardHeader.Icon {
        switch button.icon {
        case .back:
            .back { _ in button.action() }
        case .close:
            .close { _ in button.action() }
        case .chevronDown:
            DefaultModalCardHeader.Icon(
                image: .TKUIKit.Icons.Size16.chevronDown,
                size: Layout.headerIconSize,
                padding: Layout.headerIconPadding,
                onTap: { _ in button.action() }
            )
        }
    }

    var titleView: some View {
        VStack(spacing: Layout.titleDescriptionSpacing) {
            Text(viewModel.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.description)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Layout.titleTopPadding)
        .padding(.horizontal, Layout.contentHorizontalPadding)
        .padding(.bottom, Layout.titleBottomPadding)
    }

    var nameField: some View {
        HStack(spacing: 0) {
            CustomizeWalletNameTextField(
                text: $viewModel.nameInput,
                placeholder: viewModel.namePlaceholder
            )
            .focused($isNameFieldFocused)
            .onSubmit {
                isNameFieldFocused = false
            }
            .padding(.leading, Layout.nameFieldTextLeadingPadding)
            .onChange(of: viewModel.nameInput) { name in
                viewModel.setName(name)
            }

            CustomizeWalletBadgeView(
                icon: viewModel.icon,
                tintColor: viewModel.tintColor
            )
            .padding(Layout.badgePadding)
        }
        .frame(height: Layout.nameFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: Layout.nameFieldCornerRadius, style: .continuous)
                .fill(isNameFieldFocused ? .fieldBackground : .backgroundContent)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.nameFieldCornerRadius, style: .continuous)
                .strokeBorder(isNameFieldFocused ? .fieldActiveBorder : .clear, lineWidth: Layout.nameFieldBorderWidth)
        )
        .padding(.horizontal, Layout.contentHorizontalPadding)
        .padding(.vertical, Layout.nameFieldVerticalPadding)
    }

    var colorPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Layout.colorItemSpacing) {
                    ForEach(WalletTintColor.allCases, id: \.self) { color in
                        CustomizeWalletColorItemView(
                            color: color,
                            isSelected: color == viewModel.tintColor
                        ) {
                            viewModel.select(color: color)
                            withAnimation {
                                proxy.scrollTo(color, anchor: .center)
                            }
                        }
                        .id(color)
                    }
                }
                .padding(.horizontal, Layout.contentHorizontalPadding)
                .padding(.vertical, Layout.colorPickerVerticalPadding)
            }
            .tkImmediateButtonPresses()
            .onAppear {
                proxy.scrollTo(viewModel.tintColor, anchor: .center)
            }
        }
        .padding(.top, 4)
    }

    var iconPicker: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: Layout.iconItemSide),
                        spacing: Layout.iconColumnSpacing
                    ),
                ],
                spacing: Layout.iconRowSpacing
            ) {
                ForEach(Array(viewModel.icons.enumerated()), id: \.offset) { _, icon in
                    CustomizeWalletIconItemView(icon: icon) {
                        viewModel.select(icon: icon)
                    }
                }
            }
            .padding(.top, Layout.iconGridTopPadding)
            .padding(.bottom, Layout.iconGridBottomPadding + continueBarHeight)
            .padding(.horizontal, Layout.iconGridHorizontalPadding)
        }
        .tkImmediateButtonPresses()
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: Layout.iconGridTopScrimHeight)
                .tkScrim(.backgroundPage, edge: .top)
                .allowsHitTesting(false)
        }
    }

    var continueButton: some View {
        VStack(spacing: 0) {
            if !isNameFieldFocused {
                Color.clear
                    .frame(height: Layout.iconGridTopScrimHeight)
                    .tkScrim(.backgroundPage, edge: .bottom)
                    .allowsHitTesting(false)
            }
            ButtonView(
                config: ButtonView.Config(
                    title: viewModel.continueButtonTitle ?? "",
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    showsLoader: viewModel.isContinueLoading,
                    action: {
                        viewModel.didTapContinue()
                    }
                )
            )
            .disabled(!viewModel.isContinueEnabled)
            .padding(Layout.continueButtonPadding)
            .background {
                if !isNameFieldFocused {
                    TKColor.backgroundPage
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tkScrim(.backgroundPage, edge: .bottom)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ContinueBarHeightKey.self, value: geometry.size.height)
            }
        )
    }

    enum Layout {
        static let headerIconSize: CGFloat = 16
        static let headerIconPadding: CGFloat = 8
        static let contentHorizontalPadding: CGFloat = 33
        static let titleTopPadding: CGFloat = 16
        static let titleBottomPadding: CGFloat = 16
        static let titleDescriptionSpacing: CGFloat = 4

        static let nameFieldHeight: CGFloat = 64
        static let nameFieldCornerRadius: CGFloat = 16
        static let nameFieldBorderWidth: CGFloat = 1.5
        static let nameFieldTextLeadingPadding: CGFloat = 16
        static let nameFieldVerticalPadding: CGFloat = 16
        static let badgePadding: CGFloat = 8

        static let colorItemSpacing: CGFloat = 12
        static let colorPickerVerticalPadding: CGFloat = 16

        static let iconItemSide: CGFloat = 48
        static let iconRowSpacing: CGFloat = 0
        static let iconColumnSpacing: CGFloat = 0
        static let iconGridTopPadding: CGFloat = 4
        static let iconGridBottomPadding: CGFloat = 48
        static let iconGridHorizontalPadding: CGFloat = 27
        static let iconGridTopScrimHeight: CGFloat = 16

        static let continueButtonPadding = EdgeInsets(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
    }
}

private extension View {
    func pickerDimmed(_ isDimmed: Bool) -> some View {
        opacity(isDimmed ? 0.32 : 1)
            .allowsHitTesting(!isDimmed)
            .animation(.easeInOut(duration: 0.25), value: isDimmed)
    }
}

private struct CustomizeWalletNameTextField: View {
    @Binding var text: String
    let placeholder: String

    private var isPlaceholderFloating: Bool {
        !text.isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(placeholder)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .scaleEffect(
                    isPlaceholderFloating ? Layout.floatingPlaceholderScale : 1,
                    anchor: .topLeading
                )
                .offset(y: isPlaceholderFloating ? Layout.floatingPlaceholderTopInset : Layout.placeholderTopInset)
                .allowsHitTesting(false)

            TextField("", text: $text)
                .textStyle(.body1)
                .foregroundStyle(.textPrimary)
                .tint(.accentBlue)
                .submitLabel(.done)
                .frame(maxHeight: .infinity)
                .offset(y: isPlaceholderFloating ? Layout.inputFloatingYOffset : 0)
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaceholderFloating)
    }

    private enum Layout {
        static let floatingPlaceholderScale: CGFloat = 0.75
        static let floatingPlaceholderTopInset: CGFloat = 8
        static let placeholderTopInset: CGFloat = 16
        static let inputFloatingYOffset: CGFloat = 8
    }
}

private struct CustomizeWalletBadgeView: View {
    let icon: WalletIcon
    let tintColor: WalletTintColor

    @State private var iconScale: CGFloat = 1

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(Color(uiColor: tintColor.uiColor))

            iconView
                .scaleEffect(iconScale)
        }
        .frame(width: Layout.side, height: Layout.side)
        .onChange(of: icon) { _ in
            withAnimation(.easeIn(duration: 0.1)) {
                iconScale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeIn(duration: 0.1)) {
                    iconScale = 1
                }
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case let .emoji(emoji):
            Text(emoji)
                .font(.system(size: Layout.emojiFontSize))
        case let .icon(image):
            image.swiftUIImage
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white)
                .frame(width: Layout.imageSide, height: Layout.imageSide)
        }
    }

    private enum Layout {
        static let side: CGFloat = 48
        static let cornerRadius: CGFloat = 8
        static let emojiFontSize: CGFloat = 32
        static let imageSide: CGFloat = 32
    }
}

private struct CustomizeWalletColorItemView: View {
    let color: WalletTintColor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .strokeBorder(Color(uiColor: color.uiColor), lineWidth: Layout.borderWidth)

                Circle()
                    .fill(Color(uiColor: color.uiColor))
                    .padding(isSelected ? Layout.selectedFillInset : 0)
            }
            .frame(width: Layout.side, height: Layout.side)
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private enum Layout {
        static let side: CGFloat = 36
        static let borderWidth: CGFloat = 3
        static let selectedFillInset: CGFloat = 8
    }
}

private struct CustomizeWalletIconItemView: View {
    let icon: WalletIcon
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            iconView
                .frame(width: Layout.side, height: Layout.side)
                .contentShape(Rectangle())
        }
        .buttonStyle(TKTapAnimationButtonStyle())
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case let .emoji(emoji):
            Text(emoji)
                .font(.system(size: Layout.emojiFontSize))
        case let .icon(image):
            image.swiftUIImage
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.iconPrimary)
                .frame(width: Layout.imageSide, height: Layout.imageSide)
        }
    }

    private enum Layout {
        static let side: CGFloat = 48
        static let emojiFontSize: CGFloat = 36
        static let imageSide: CGFloat = 32
    }
}
