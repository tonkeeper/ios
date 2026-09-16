import Foundation

public struct OnboardingRootScreenState {
    public let title: String
    public let caption: String
    public let createButtonTitle: String
    public let importButtonTitle: String
    public let termsCaption: String
    public let termsLinkTitle: String
    public let termsURL: URL?

    public init(
        title: String,
        caption: String,
        createButtonTitle: String,
        importButtonTitle: String,
        termsCaption: String,
        termsLinkTitle: String,
        termsURL: URL?
    ) {
        self.title = title
        self.caption = caption
        self.createButtonTitle = createButtonTitle
        self.importButtonTitle = importButtonTitle
        self.termsCaption = termsCaption
        self.termsLinkTitle = termsLinkTitle
        self.termsURL = termsURL
    }
}
