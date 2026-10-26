import Kingfisher
import SwiftUI

/// Loads a remote image; the only sanctioned `KFImage` host (swiftlint `prefer_tk_remote_image`).
/// Shows `failure` once a load fails, while a load cancelled on disappear restarts on the next appear.
public struct TKRemoteImage<Placeholder: View, Failure: View>: View {
    @Environment(\.displayScale) private var displayScale
    @State private var failedSource: Source?

    private let source: Source
    private let alternativeSources: [Source]
    private let downsampleSize: CGSize?
    private let contentMode: SwiftUI.ContentMode
    private let placeholder: () -> Placeholder
    private let failure: () -> Failure

    public init(
        source: Source,
        alternativeSources: [Source] = [],
        downsampleSize: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.source = source
        self.alternativeSources = alternativeSources
        self.downsampleSize = downsampleSize
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.failure = failure
    }

    public init(
        url: URL,
        downsampleSize: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.init(
            source: .network(url),
            downsampleSize: downsampleSize,
            contentMode: contentMode,
            placeholder: placeholder,
            failure: failure
        )
    }

    public var body: some View {
        if failedSource == source {
            failure()
        } else {
            KFImage
                .source(source)
                .alternativeSources(alternativeSources)
                .setProcessor(processor)
                .loadDiskFileSynchronously()
                .placeholder { placeholder() }
                .onFailure { [source] error in
                    guard !error.isTaskCancelled else { return }
                    failedSource = source
                }
                .cancelOnDisappear(true)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        }
    }

    private var processor: ImageProcessor {
        guard let downsampleSize else {
            return DefaultImageProcessor.default
        }
        return DownsamplingImageProcessor(
            size: CGSize(
                width: max(downsampleSize.width, 1) * displayScale,
                height: max(downsampleSize.height, 1) * displayScale
            )
        )
    }
}
