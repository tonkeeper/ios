import Lottie
import SwiftUI
import TKUIKit

struct RaffleConfettiView: View {
    var body: some View {
        GeometryReader { geometry in
            let sideWidth = geometry.size.width / 2
            HStack(spacing: 0) {
                RaffleConfettiSide(resource: .confettiLeft)
                RaffleConfettiSide(resource: .confettiRight)
            }
            .frame(height: sideWidth * Layout.sideHeightRatio)
            .offset(y: Layout.topOffset)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private enum Layout {
        static let sideHeightRatio: CGFloat = 540 / 187
        static let topOffset: CGFloat = 100
    }
}

private struct RaffleConfettiSide: View {
    let resource: LottieResource

    @State private var playbackMode: LottiePlaybackMode = .paused(at: .progress(0))

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
        .onAppear {
            playbackMode = .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
        }
    }
}
