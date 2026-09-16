import SwiftUI
import TKUIKit
import UIKit

struct NFTDetailsHeroView: View {
    let imageSource: NFTImageViewImageSource
    let lottieURL: URL?
    let isBlurred: Bool
    let isOnSale: Bool

    @State private var width: CGFloat = 0
    @State private var isLottieLoaded = false

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: width)
            .clipped()
            .overlay(alignment: .topTrailing) {
                saleBadge
            }
            .background(widthReader)
            .onPreferenceChange(NFTDetailsHeroWidthPreferenceKey.self) { width = $0 }
    }
}

private extension NFTDetailsHeroView {
    @ViewBuilder
    var saleBadge: some View {
        if isOnSale {
            Image.TKUIKit.Icons.Size32.saleBadge
                .resizable()
                .frame(
                    width: Layout.saleBadgeSide,
                    height: Layout.saleBadgeSide
                )
                .shadow(color: .constantBlack.opacity(0.08), radius: 6, y: 2)
                .padding(Layout.saleBadgePadding)
        }
    }

    var content: some View {
        ZStack {
            // Only once the square side is measured: a remote image starts loading with a
            // downsampling size taken from this configuration, and that load is keyed on the URL, so
            // one started at zero size never recovers.
            if width > 0, !isLottieLoaded {
                NFTImageView(
                    imageSource: imageSource,
                    configuration: NFTImageView.Configuration(
                        imageWidth: width,
                        imageHeight: width,
                        cardWidth: width,
                        cardHeight: width
                    )
                )
            }

            if let lottieURL {
                NFTDetailsLottieView(
                    url: lottieURL,
                    onLoaded: { isLottieLoaded = true },
                    onError: { isLottieLoaded = false }
                )
                .opacity(isLottieLoaded ? 1 : 0)
            }

            if isBlurred {
                NFTDetailsSecureBlurView()
            }
        }
    }

    enum Layout {
        static let saleBadgeSide: CGFloat = 32
        static let saleBadgePadding: CGFloat = 8
    }

    var widthReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: NFTDetailsHeroWidthPreferenceKey.self,
                value: proxy.size.width
            )
        }
    }
}

private struct NFTDetailsHeroWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct NFTDetailsSecureBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> TKSecureBlurView {
        TKSecureBlurView()
    }

    func updateUIView(_ uiView: TKSecureBlurView, context: Context) {}
}

private struct NFTDetailsLottieView: UIViewRepresentable {
    let url: URL
    let onLoaded: () -> Void
    let onError: () -> Void

    func makeUIView(context: Context) -> TKLottieWebView {
        let view = TKLottieWebView()
        view.backgroundColor = .clear
        apply(to: view, context: context)
        return view
    }

    func updateUIView(_ uiView: TKLottieWebView, context: Context) {
        apply(to: uiView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadedURL: URL?
    }

    /// Reloading is keyed on the URL so that re-renders caused by the load callbacks do not restart
    /// the animation.
    private func apply(to view: TKLottieWebView, context: Context) {
        view.onLoaded = onLoaded
        view.onError = { _ in onError() }

        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        view.loadLottieAnimation(url: url)
    }
}
