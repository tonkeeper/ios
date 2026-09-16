import SwiftUI

public struct TKHintTextView: View {
    enum Layout {
        static let tailCornerRadius: CGFloat = 3
        static let tailSize = CGSize(width: 12, height: 6)
        static let tailOffset: CGFloat = 24
        static let insets = EdgeInsets(
            top: 10,
            leading: 16,
            bottom: 10,
            trailing: 16
        )
    }

    private let text: String
    private let position: HintPosition.Direction?
    private let contentInsets: EdgeInsets

    public init(
        text: String,
        position: HintPosition.Direction? = nil,
        contentInsetsModifier: (inout EdgeInsets) -> Void = { _ in }
    ) {
        self.text = text
        self.position = position
        self.contentInsets = {
            var insets = Layout.insets
            contentInsetsModifier(&insets)
            return insets
        }()
    }

    public var body: some View {
        Text(text)
            .textStyle(.body2)
            .foregroundStyle(.textPrimary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(contentInsets)
            .withTail(
                appearance: Self.appearance,
                parameters: Self.tailParameters,
                direction: position
            )
    }
}

extension TKHintTextView: HintView {
    public static var tailParameters: HintTailParameters? {
        HintTailParameters(
            horizontalOffset: Layout.tailOffset,
            size: Layout.tailSize,
            tailCornerRadius: Layout.tailCornerRadius
        )
    }
}

#Preview {
    VStack(spacing: 48) {
        ZStack(alignment: .bottomTrailing) {
            TKHintTextView(
                text: "Top Left",
                position: .topLeft
            )
            .border(.red)

            VStack(
                alignment: .trailing,
                spacing: TKHintTextView.Layout.tailSize.height - 2
            ) {
                Rectangle()
                    .frame(width: TKHintTextView.Layout.tailSize.width, height: 1)
                    .foregroundStyle(.green)
                    .padding(.trailing, TKHintTextView.Layout.tailOffset - TKHintTextView.Layout.tailSize.width / 2)
                Rectangle()
                    .frame(width: TKHintTextView.Layout.tailOffset, height: 1)
                    .foregroundStyle(.cyan)
            }
        }

        ZStack(alignment: .bottomLeading) {
            TKHintTextView(
                text: "Top Right",
                position: .topRight
            )
            .border(.red)
            VStack(
                alignment: .leading,
                spacing: TKHintTextView.Layout.tailSize.height - 2
            ) {
                Rectangle()
                    .frame(width: TKHintTextView.Layout.tailSize.width, height: 1)
                    .foregroundStyle(.green)
                    .padding(.leading, TKHintTextView.Layout.tailOffset - TKHintTextView.Layout.tailSize.width / 2)
                Rectangle()
                    .frame(width: TKHintTextView.Layout.tailOffset, height: 1)
                    .foregroundStyle(.cyan)
            }
        }

        TKHintTextView(
            text: "Top Center",
            position: .topCenter
        )
        .border(.red)

        TKHintTextView(
            text: "No Tail",
            position: nil
        )
        .border(.red)

        TKHintTextView(
            text: "Bottom Center",
            position: .bottomCenter
        )
        .border(.red)

        ZStack(alignment: .topTrailing) {
            TKHintTextView(
                text: "Bottom Left",
                position: .bottomLeft
            )
            .border(.red)
            VStack(
                alignment: .trailing,
                spacing: TKHintTextView.Layout.tailSize.height - 2
            ) {
                Rectangle()
                    .frame(width: TKHintTextView.Layout.tailOffset, height: 1)
                    .foregroundStyle(.cyan)
                Rectangle()
                    .frame(width: TKHintTextView.Layout.tailSize.width, height: 1)
                    .foregroundStyle(.green)
                    .padding(.trailing, TKHintTextView.Layout.tailOffset - TKHintTextView.Layout.tailSize.width / 2)
            }
        }

        ZStack(alignment: .topLeading) {
            TKHintTextView(
                text: "Bottom Right",
                position: .bottomRight
            )
            .border(.red)
            VStack(
                alignment: .leading,
                spacing: TKHintTextView.Layout.tailSize.height - 2
            ) {
                Rectangle()
                    .frame(width: TKHintTextView.Layout.tailOffset, height: 1)
                    .foregroundStyle(.cyan)
                Rectangle()
                    .frame(width: TKHintTextView.Layout.tailSize.width, height: 1)
                    .foregroundStyle(.green)
                    .padding(.leading, TKHintTextView.Layout.tailOffset - TKHintTextView.Layout.tailSize.width / 2)
            }
        }
    }
}
