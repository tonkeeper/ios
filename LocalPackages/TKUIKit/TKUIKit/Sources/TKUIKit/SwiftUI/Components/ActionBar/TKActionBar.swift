import SwiftUI
import UIKit

public enum TKActionBarProcess: Equatable {
    case idle
    case processing
    case success
    case failure
}

public struct TKActionBar<Content: View>: View {
    private let process: TKActionBarProcess
    private let successTitle: String
    private let failureTitle: String
    private let content: Content

    public init(
        process: TKActionBarProcess = .idle,
        successTitle: String,
        failureTitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.process = process
        self.successTitle = successTitle
        self.failureTitle = failureTitle
        self.content = content()
    }

    public var body: some View {
        ZStack {
            switch process {
            case .idle:
                content
            case .processing:
                CircularLoader(mode: .indeterminate, preset: .medium)
            case .success:
                TKResultSwiftUIView(state: .success, title: successTitle)
            case .failure:
                TKResultSwiftUIView(state: .failure, title: failureTitle)
            }
        }
        .frame(maxWidth: .infinity, minHeight: ActionBarLayout.contentHeight)
        .padding(ActionBarLayout.inset)
        .animation(.easeInOut(duration: ActionBarLayout.transitionDuration), value: process)
        .onChange(of: process) { process in
            switch process {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .failure:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .idle, .processing:
                break
            }
        }
    }
}

public extension View {
    @MainActor
    @ViewBuilder
    func tkScrollEdgeBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26.0, *), TKLiquidGlass.isEnabled {
            safeAreaBar(edge: .bottom, spacing: 0) {
                bar()
                    .background { ActionBarFade() }
            }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                bar()
                    .background { ActionBarFade() }
            }
        }
    }
}

private struct ActionBarFade: View {
    var body: some View {
        TKColor.backgroundPage
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.6), location: 0.35),
                        .init(color: .black.opacity(0.95), location: 0.6),
                        .init(color: .black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .bottom)
    }
}

private enum ActionBarLayout {
    static let contentHeight: CGFloat = 56
    static let inset: CGFloat = 16
    static let transitionDuration: TimeInterval = 0.2
}
