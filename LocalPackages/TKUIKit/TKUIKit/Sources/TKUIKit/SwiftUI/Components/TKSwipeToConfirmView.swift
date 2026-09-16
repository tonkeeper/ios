import SwiftUI

/// SwiftUI swipe-to-confirm control. The UIKit equivalent is `TKSlider`; this is the
/// native version for SwiftUI screens. Bump `resetToken` to spring the handle back to
/// idle after a confirm that didn't dismiss the screen (e.g. a canceled action).
public struct TKSwipeToConfirmView: View {
    public enum Appearance {
        case standard
        case warning

        func handleColor(_ palette: TKPalette) -> Color {
            switch self {
            case .standard: palette.button.primaryBackground
            case .warning: palette.accent.orange
            }
        }
    }

    @Environment(\.tkPalette) private var palette

    private let title: String
    private let subtitle: String?
    private let appearance: Appearance
    private let isEnabled: Bool
    private let resetToken: Int
    private let handleAccessibilityIdentifier: String?
    private let onConfirm: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isLocked = false

    public init(
        title: String,
        subtitle: String? = nil,
        appearance: Appearance = .standard,
        isEnabled: Bool = true,
        resetToken: Int = 0,
        handleAccessibilityIdentifier: String? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.appearance = appearance
        self.isEnabled = isEnabled
        self.resetToken = resetToken
        self.handleAccessibilityIdentifier = handleAccessibilityIdentifier
        self.onConfirm = onConfirm
    }

    public var body: some View {
        GeometryReader { proxy in
            let maxOffset = max(0, proxy.size.width - Layout.handleWidth)
            let progress = maxOffset > 0 ? Double(dragOffset / maxOffset) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .fill(.backgroundContent)
                label
                    .frame(maxWidth: .infinity)
                    .opacity(1 - progress)
                handle
                    .offset(x: dragOffset)
                    .gesture(dragGesture(maxOffset: maxOffset))
            }
        }
        .frame(height: Layout.height)
        .opacity(isEnabled ? 1 : Layout.disabledOpacity)
        .allowsHitTesting(isEnabled)
        .onChange(of: resetToken) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dragOffset = 0 }
            isLocked = false
        }
    }

    private var label: some View {
        VStack(spacing: -2) {
            Text(title)
                .textStyle(.label2)
                .foregroundStyle(.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .textStyle(.body3)
                    .foregroundStyle(.textTertiary)
            }
        }
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(appearance.handleColor(palette))
            .frame(width: Layout.handleWidth, height: Layout.height)
            .overlay {
                Image(uiImage: isLocked ? .TKUIKit.Icons.Size28.donemarkOutline : .TKUIKit.Icons.Size28.arrowRightOutline)
                    .renderingMode(.template)
                    .foregroundStyle(.buttonPrimaryForeground)
            }
            .accessibilityIdentifier(handleAccessibilityIdentifier ?? "")
    }

    private func dragGesture(maxOffset: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = min(max(0, value.translation.width), maxOffset)
                let locked = dragOffset >= maxOffset
                guard locked != isLocked else { return }
                isLocked = locked
                if locked { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
            .onEnded { _ in
                if isLocked {
                    onConfirm()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dragOffset = 0 }
                }
            }
    }

    private enum Layout {
        static let height: CGFloat = 56
        static let handleWidth: CGFloat = 92
        static let cornerRadius: CGFloat = 16
        static let disabledOpacity: CGFloat = 0.48
    }
}
