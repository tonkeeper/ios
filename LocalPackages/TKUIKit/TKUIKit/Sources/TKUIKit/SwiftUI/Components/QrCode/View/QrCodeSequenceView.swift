import Combine
import SwiftUI

public struct QrCodeSequenceView<Overlay: View>: View {
    let matrices: [QrCodeMatrix]
    let configuration: QrCodeGeneratorConfiguration
    let style: QrCodeStyle
    let rippleConfiguration: QrCodeRippleConfiguration
    let interactionMode: QrCodeInteractionMode
    let frameDuration: TimeInterval
    private let overlay: () -> Overlay

    @State private var currentIndex = 0

    public init(
        matrices: [QrCodeMatrix],
        configuration: QrCodeGeneratorConfiguration = .default,
        style: QrCodeStyle = QrCodeStyle(),
        rippleConfiguration: QrCodeRippleConfiguration = .default,
        interactionMode: QrCodeInteractionMode = .tapOnly,
        frameDuration: TimeInterval = 0.1,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.matrices = matrices
        self.configuration = configuration
        self.style = style
        self.rippleConfiguration = rippleConfiguration
        self.interactionMode = interactionMode
        self.frameDuration = frameDuration
        self.overlay = overlay
    }

    public var body: some View {
        Group {
            if let currentMatrix {
                QrCodeView(
                    matrix: currentMatrix,
                    configuration: configuration,
                    style: style,
                    rippleConfiguration: rippleConfiguration,
                    interactionMode: interactionMode,
                    overlay: overlay
                )
                .transaction { transaction in
                    transaction.disablesAnimations = true
                    transaction.animation = nil
                }
            } else {
                Color.clear
            }
        }
        .onReceive(timer) { _ in
            guard matrices.count > 1 else {
                return
            }
            currentIndex = (currentIndex + 1) % matrices.count
        }
        .onChange(of: matrices.count) { count in
            guard count > 0 else {
                currentIndex = 0
                return
            }
            currentIndex = currentIndex % count
        }
    }

    private var currentMatrix: QrCodeMatrix? {
        guard !matrices.isEmpty else {
            return nil
        }
        return matrices[currentIndex % matrices.count]
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(
            every: max(QrCodeViewLayout.minimumFrameDuration, frameDuration),
            on: .main,
            in: .common
        )
        .autoconnect()
    }
}

public extension QrCodeSequenceView where Overlay == EmptyView {
    init(
        matrices: [QrCodeMatrix],
        configuration: QrCodeGeneratorConfiguration = .default,
        style: QrCodeStyle = QrCodeStyle(),
        rippleConfiguration: QrCodeRippleConfiguration = .default,
        interactionMode: QrCodeInteractionMode = .tapOnly,
        frameDuration: TimeInterval = 0.1
    ) {
        self.init(
            matrices: matrices,
            configuration: configuration,
            style: style,
            rippleConfiguration: rippleConfiguration,
            interactionMode: interactionMode,
            frameDuration: frameDuration,
            overlay: {
                EmptyView()
            }
        )
    }
}
