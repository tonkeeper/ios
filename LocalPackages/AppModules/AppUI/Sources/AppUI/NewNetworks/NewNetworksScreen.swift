import SwiftUI
import TKLocalize
import TKUIKit

/// Shown after the passcode when the user's wallets miss chains the app now supports. The orbit
/// holds one icon per chain in `state.chains` (icons shrink as their number grows), spins while
/// `state.phase` is loading and stops in its resting position before revealing the result: the
/// added chains turn from grey to colour, confetti drops and the button appears. The close button
/// lets the user leave in any state, the loading one included.
public struct NewNetworksScreen: View {
    private let state: NewNetworksScreenState
    private let onContinue: () -> Void
    private let onRetry: () -> Void
    private let onClose: () -> Void

    /// With system animations off the design asks for no fly-out, rotation or confetti.
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.newNetworksMotion) private var motion

    private var reduceMotion: Bool {
        accessibilityReduceMotion || !motion
    }

    /// What the text, buttons and confetti show. With motion it lags behind `state.phase` until
    /// the orbit settles; without motion it follows it at once.
    @State private var shownPhase = NewNetworksScreenState.Phase.loading
    @State private var timeline = NewNetworksOrbitTimeline(start: Date())
    @State private var isOrbitSettled = false
    @State private var didAppear = false

    public init(
        state: NewNetworksScreenState,
        onContinue: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.state = state
        self.onContinue = onContinue
        self.onRetry = onRetry
        self.onClose = onClose
    }

    public var body: some View {
        GeometryReader { proxy in
            let fullHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let scale = NewNetworksMotion.scale(for: CGSize(width: proxy.size.width, height: fullHeight))
            // The design measures its centres from the top of the screen; the reader starts below
            // the status bar.
            let centerY = fullHeight / 2 - proxy.safeAreaInsets.top

            ZStack(alignment: .top) {
                header

                if !reduceMotion {
                    confetti(scale: scale)
                        .offset(y: NewNetworksMotion.confettiTop * scale - proxy.safeAreaInsets.top)
                }

                NewNetworksOrbitView(
                    chains: state.chains,
                    addedIds: addedIds,
                    timeline: reduceMotion ? nil : timeline,
                    isPaused: reduceMotion || isOrbitSettled,
                    scale: scale
                )
                .position(x: proxy.size.width / 2, y: centerY + NewNetworksMotion.orbitCenterOffset * scale)

                statusText(width: proxy.size.width)
                    .position(x: proxy.size.width / 2, y: centerY + NewNetworksMotion.textCenterOffset * scale)

                actions
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(TKColor.backgroundPage.ignoresSafeArea())
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            timeline = NewNetworksOrbitTimeline(start: Date())
        }
        .task(id: state.phase) {
            await settle(on: state.phase)
        }
    }
}

private extension NewNetworksScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                rightIcon: .close { _ in onClose() },
                height: .compact
            )
        )
    }

    func confetti(scale: CGFloat) -> some View {
        let isShown = shownPhase.isAdded
        return NewNetworksConfettiView(isPlaying: isShown, scale: scale)
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : -NewNetworksMotion.confettiRise * scale)
            .animation(.newNetworksStandard(duration: NewNetworksMotion.confettiDuration), value: isShown)
    }

    func statusText(width: CGFloat) -> some View {
        ZStack {
            VStack(spacing: Layout.titleSpacing) {
                Text(title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                Text(subtitle)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Layout.textHorizontalPadding)
            .padding(.bottom, Layout.textBottomPadding)
            .id(shownPhase.key)
            .transition(swapTransition(offset: Layout.textSwapOffset, blur: 6))
        }
        .frame(width: width)
        .animation(swapAnimation, value: shownPhase.key)
    }

    var actions: some View {
        ZStack {
            actionsContent
                .id(shownPhase.key)
                .transition(swapTransition(offset: Layout.actionsSwapOffset, blur: 4))
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.actionBarPadding)
        .background(.backgroundTransparent, ignoresSafeAreaEdges: .bottom)
        .animation(swapAnimation, value: shownPhase.key)
    }

    @ViewBuilder
    var actionsContent: some View {
        switch shownPhase {
        case .loading:
            CircularLoader(mode: .indeterminate, preset: .medium)
                .frame(maxWidth: .infinity)
                .frame(height: NewNetworksMotion.loaderRowHeight)
        case .added:
            continueButton(appearance: .primary)
        case .error:
            VStack(spacing: Layout.actionSpacing) {
                ButtonView(
                    config: ButtonView.Config(
                        title: TKLocales.NewNetworks.tryAgain,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .primary,
                        action: onRetry
                    )
                )
                // The missing chains are retried on the next launch.
                continueButton(appearance: .secondary)
            }
        }
    }

    func continueButton(appearance: ButtonView.Appearance) -> ButtonView {
        ButtonView(
            config: ButtonView.Config(
                title: TKLocales.NewNetworks.openWallet,
                size: .large,
                layoutMode: .fill,
                appearance: appearance,
                action: onContinue
            )
        )
    }

    var title: String {
        switch shownPhase {
        case .loading:
            TKLocales.NewNetworks.Loading.title
        case .added:
            TKLocales.NewNetworks.Added.title
        case .error:
            TKLocales.NewNetworks.Error.title
        }
    }

    var subtitle: String {
        switch shownPhase {
        case .loading:
            return TKLocales.NewNetworks.Loading.subtitle
        case let .added(ids):
            let added = state.chains.filter { ids.contains($0.id) }
            return Self.addedSubtitle(chains: added.isEmpty ? state.chains : added)
        case .error:
            return TKLocales.NewNetworks.Error.subtitle
        }
    }

    /// "Solana, Robinhood, Polygon and Avalanche are now in your wallet."
    static func addedSubtitle(chains: [NewNetworksScreenState.Chain]) -> String {
        let names = chains.map(\.title)
        guard names.count > 1, let last = names.last else {
            return TKLocales.NewNetworks.Added.subtitleOne(names.first ?? "")
        }
        return TKLocales.NewNetworks.Added.subtitleMany(
            TKLocales.NewNetworks.listLast(names.dropLast().joined(separator: ", "), last)
        )
    }

    /// The result's chains, coloured once the orbit settles.
    var addedIds: Set<String> {
        guard case let .added(ids) = state.phase else { return [] }
        return ids
    }

    var swapAnimation: Animation? {
        reduceMotion ? nil : .newNetworksStandard(duration: 0.4)
    }

    /// Outgoing content blurs while it fades up, incoming content sharpens as it rises into place.
    func swapTransition(offset: CGFloat, blur: CGFloat) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .modifier(
                active: SwapModifier(opacity: 0, offset: offset, blur: blur),
                identity: SwapModifier(opacity: 1, offset: 0, blur: 0)
            )
            .animation(.newNetworksStandard(duration: 0.4, delay: 0.1)),
            removal: .modifier(
                active: SwapModifier(opacity: 0, offset: -offset, blur: blur),
                identity: SwapModifier(opacity: 1, offset: 0, blur: 0)
            )
            .animation(.newNetworksStandard(duration: 0.25))
        )
    }

    func settle(on phase: NewNetworksScreenState.Phase) async {
        guard !reduceMotion else {
            shownPhase = phase
            return
        }
        switch phase {
        case .loading:
            shownPhase = .loading
            isOrbitSettled = false
            if timeline.finish != nil {
                timeline.restartLoop(at: Date())
            }
        case .added, .error:
            let now = Date()
            timeline.startFinish(at: now, count: state.chains.count)
            guard await Self.sleep(until: timeline.revealDate ?? now) else { return }
            shownPhase = phase
            guard await Self.sleep(seconds: NewNetworksMotion.revealBeforeStop + NewNetworksMotion.settleDuration) else { return }
            isOrbitSettled = true
        }
    }

    /// False when the wait was cancelled by the next phase.
    static func sleep(until date: Date) async -> Bool {
        await sleep(seconds: date.timeIntervalSinceNow)
    }

    static func sleep(seconds: TimeInterval) async -> Bool {
        guard seconds > 0 else { return !Task.isCancelled }
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return true
        } catch {
            return false
        }
    }

    enum Layout {
        static let titleSpacing: CGFloat = 4
        static let textHorizontalPadding: CGFloat = 32
        static let textBottomPadding: CGFloat = 16
        static let textSwapOffset: CGFloat = 8
        static let actionsSwapOffset: CGFloat = 16
        static let actionBarPadding: CGFloat = 16
        static let actionSpacing: CGFloat = 16
    }
}

private struct SwapModifier: ViewModifier {
    let opacity: Double
    let offset: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(y: offset)
            .blur(radius: blur)
    }
}

private extension NewNetworksScreenState.Phase {
    var key: Int {
        switch self {
        case .loading: 0
        case .added: 1
        case .error: 2
        }
    }

    var isAdded: Bool {
        guard case .added = self else { return false }
        return true
    }
}

private extension Animation {
    /// Figma's Easy Ease.
    static func newNetworksStandard(duration: Double, delay: Double = 0) -> Animation {
        .timingCurve(0.33, 0, 0.67, 1, duration: duration).delay(delay)
    }
}

/// Reduced motion cannot be set on the environment, so a static preview turns the motion off here.
private struct NewNetworksMotionKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var newNetworksMotion: Bool {
        get { self[NewNetworksMotionKey.self] }
        set { self[NewNetworksMotionKey.self] = newValue }
    }
}
