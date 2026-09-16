import SwiftUI

public struct SearchField: View {
    @Environment(\.tkPalette) private var palette

    let contentInsets: EdgeInsets
    let title: String
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding?
    let allowsTextInput: Bool
    let shimmer: Bool
    let accessibilityIdentifier: String?

    public init(
        insetsModifier: (inout EdgeInsets) -> Void = { _ in },
        title: String,
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding? = nil,
        allowsTextInput: Bool = true,
        shimmer: Bool = false,
        accessibilityIdentifier: String? = nil
    ) {
        contentInsets = {
            var insets = Layout.edgeInsets
            insetsModifier(&insets)
            return insets
        }()
        _text = text
        self.title = title
        self.isFocused = isFocused
        self.allowsTextInput = allowsTextInput
        self.shimmer = shimmer
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        HStack(spacing: 12) {
            SwiftUI.Image.TKUIKit.Icons.Size16.magnifyingGlass
                .renderingMode(.template)
                .foregroundStyle(.iconSecondary)

            if allowsTextInput {
                TextField("", text: $text, prompt: Text(title).foregroundColor(palette.text.secondary))
                    .font(Font(UIFont.tkRegular(size: 16, features: .text)))
                    .foregroundStyle(.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .tint(.accentBlue)
                    .applyTradeSearchFocus(isFocused)
                    .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                Text(text.isEmpty ? title : text)
                    .font(Font(UIFont.tkRegular(size: 16, features: .text)))
                    .foregroundStyle(
                        text.isEmpty ? palette.text.secondary : palette.text.primary
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(accessibilityIdentifier)
            }

            if allowsTextInput, !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    SwiftUI.Image.TKUIKit.Icons.Size16.xmarkCircle
                        .renderingMode(.template)
                        .foregroundStyle(.iconSecondary)
                }
                .buttonStyle(TKTapAnimationButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.backgroundContent)
        )
        .shimmer(shimmer)
        .padding(contentInsets)
    }
}

extension SearchField {
    enum Layout {
        static let edgeInsets: EdgeInsets = EdgeInsets(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
    }
}

private extension View {
    @ViewBuilder
    func applyTradeSearchFocus(_ binding: FocusState<Bool>.Binding?) -> some View {
        if let binding {
            focused(binding)
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        SearchField(
            title: "Search by ticker or name",
            text: .constant("")
        )
        SearchField(
            title: "Search by ticker or name",
            text: .constant("123")
        )
        SearchField(
            title: "Search by ticker or name",
            text: .constant(""),
            allowsTextInput: false
        )
    }
    .padding(.horizontal, 12)
    .debugPreview(background: .page)
    .tkPreviewTheme(.deepBlue)
}
