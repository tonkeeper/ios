import Lottie
import SwiftUI
import TKLocalize
import TKLogging
import TKUIKit

struct VerifiedTokenInfoPopupView: View {
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AssetInfoPopupLottieView(resource: .verificationCheckmark)
                .frame(
                    width: Layout.lottieSize,
                    height: Layout.lottieSize
                )
                .padding(.bottom, Layout.lottieBottomInset)

            VStack(spacing: Layout.titleSpacing) {
                Text(TKLocales.Token.verified)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Text(TKLocales.Token.VerifiedPopup.caption)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, Layout.titleTopPadding)
            .padding(.horizontal, Layout.titleHorizontalInset)
            .padding(.bottom, Layout.titleBottomInset)

            ButtonView(
                config: .init(
                    title: TKLocales.Actions.ok,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: dismiss
                )
            )
            .padding([.top, .leading, .trailing], Layout.buttonInset)
            .padding(.bottom, Layout.bottomInset)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: .top)
    }
}

private struct AssetInfoPopupLottieView: View {
    let resource: LottieResource

    @State private var playbackMode: LottiePlaybackMode

    init(resource: LottieResource) {
        self.resource = resource
        _playbackMode = State(initialValue: .paused(at: .progress(0)))
    }

    var body: some View {
        LottieView(
            animation: LottieAnimation.named(
                resource.name,
                bundle: resource.bundle,
                subdirectory: resource.subdirectory
            )
        )
        .resizable()
        .playbackMode(playbackMode)
        .configure { $0.backgroundBehavior = .pauseAndRestore }
        .allowsHitTesting(false)
        .onAppear {
            Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: 150 * NSEC_PER_MSEC)
                } catch {
                    Log.w("failed to delay verified token animation due to error: \(error)")
                    return
                }
                playbackMode = .playing(
                    .fromProgress(nil, toProgress: 1, loopMode: .playOnce)
                )
            }
        }
    }
}

private extension VerifiedTokenInfoPopupView {
    enum Layout {
        static let lottieSize: CGFloat = 84
        static let lottieBottomInset: CGFloat = 12
        static let titleTopPadding: CGFloat = 1
        static let titleSpacing: CGFloat = 3
        static let titleHorizontalInset: CGFloat = 32
        static let titleBottomInset: CGFloat = 16
        static let buttonInset: CGFloat = 16
        static let bottomInset: CGFloat = 3
    }
}
