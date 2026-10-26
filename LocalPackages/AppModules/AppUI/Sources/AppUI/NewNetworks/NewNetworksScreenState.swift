import UIKit

public struct NewNetworksScreenState: Equatable {
    public struct Chain: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let icon: UIImage
        /// Read once off the logo: the grey loading look keeps the glyph and drops the background.
        let luminance: NewNetworksGlyphLuminance

        public init(id: String, title: String, icon: UIImage) {
            self.id = id
            self.title = title
            self.icon = icon
            luminance = icon.glyphLuminance
        }
    }

    public enum Phase: Equatable {
        case loading
        /// Only the chains that got added, by id: the rest of the orbit stays grey.
        case added(Set<String>)
        /// Nothing was added.
        case error
    }

    public var chains: [Chain]
    public var phase: Phase

    public init(chains: [Chain], phase: Phase) {
        self.chains = chains
        self.phase = phase
    }
}
