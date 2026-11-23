public struct StoriesCloseAlertModel {
    public let title: String
    public let markdownMessage: String
    public let skipTitle: String
    public let continueTitle: String

    public init(
        title: String,
        markdownMessage: String,
        skipTitle: String,
        continueTitle: String
    ) {
        self.title = title
        self.markdownMessage = markdownMessage
        self.skipTitle = skipTitle
        self.continueTitle = continueTitle
    }
}
