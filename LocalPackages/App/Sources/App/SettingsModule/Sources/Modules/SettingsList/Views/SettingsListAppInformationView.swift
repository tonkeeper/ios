import Lottie
import SwiftUI
import TKUIKit

struct SettingsListAppInformationView: View {
    let information: SettingsListAppInformation
    let onDevMenuActivation: () -> Void

    @State private var tapCount = 0
    @State private var tapResetWork: DispatchWorkItem?
    @State private var playbackMode: LottiePlaybackMode = .paused(at: .progress(0))

    var body: some View {
        VStack(spacing: 0) {
            mark

            Text(information.appName)
                .textStyle(.label2)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .padding(.top, Layout.namePadding)

            Text(information.version)
                .textStyle(.body3)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Layout.topPadding)
    }
}

private extension SettingsListAppInformationView {
    var mark: some View {
        LottieView(
            animation: markAnimation
        )
        .playbackMode(playbackMode)
        .animationDidFinish { _ in
            playbackMode = .paused(at: .progress(0))
        }
        .configure { $0.backgroundBehavior = .pauseAndRestore }
        .frame(height: Layout.markHeight, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityIdentifier("settings_app_information")
        .onTapGesture {
            playbackMode = .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
            countTap()
        }
    }

    var markAnimation: LottieAnimation? {
        LottieAnimation.named(
            LottieResource.keeperLogo.name,
            bundle: LottieResource.keeperLogo.bundle,
            subdirectory: LottieResource.keeperLogo.subdirectory
        )
    }

    func countTap() {
        tapCount += 1
        if tapCount >= Layout.devMenuActivationTapCount {
            onDevMenuActivation()
        }
        // The series ends one second after the *last* tap, not the first: a reset armed by the
        // first tap also cut off a sequence that merely took longer than a second (UI tests tap
        // at about two taps a second).
        tapResetWork?.cancel()
        let work = DispatchWorkItem { tapCount = 0 }
        tapResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    enum Layout {
        static let devMenuActivationTapCount = 5

        static let markHeight: CGFloat = 40
        static let topPadding: CGFloat = 12
        static let namePadding: CGFloat = 4
    }
}
