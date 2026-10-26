import Lottie
import SwiftUI
import TKUIKit

/// Two Lottie halves that drop once over the orbit and stay clear of the text below it.
struct NewNetworksConfettiView: View {
    let isPlaying: Bool
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            half(.newNetworksConfettiLeft)
            half(.newNetworksConfettiRight)
        }
        .offset(y: NewNetworksMotion.confettiAreaTop * scale)
        .frame(height: NewNetworksMotion.confettiHeight * scale, alignment: .top)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func half(_ resource: LottieResource) -> some View {
        LottieView(
            animation: LottieAnimation.named(
                resource.name,
                bundle: resource.bundle,
                subdirectory: resource.subdirectory
            )
        )
        .resizable()
        .playbackMode(
            isPlaying
                ? .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
                : .paused(at: .progress(0))
        )
        .aspectRatio(NewNetworksMotion.confettiHalfAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}
