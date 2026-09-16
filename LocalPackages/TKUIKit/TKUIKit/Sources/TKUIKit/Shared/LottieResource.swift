import Foundation

public struct LottieResource: Equatable {
    public let name: String
    public let bundle: Bundle
    public let subdirectory: String?

    public init(
        name: String,
        bundle: Bundle,
        subdirectory: String? = nil
    ) {
        self.name = name
        self.bundle = bundle
        self.subdirectory = subdirectory
    }

    public static func == (lhs: LottieResource, rhs: LottieResource) -> Bool {
        lhs.name == rhs.name
            && lhs.subdirectory == rhs.subdirectory
            && lhs.bundle.bundleURL == rhs.bundle.bundleURL
    }
}
