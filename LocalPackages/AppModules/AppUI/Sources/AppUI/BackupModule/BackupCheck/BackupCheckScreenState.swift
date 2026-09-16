public struct BackupCheckScreenState {
    public struct Row: Identifiable {
        public let id: Int
        public let number: Int
        public let options: [String]
        public let selectedOption: String?

        public init(
            id: Int,
            number: Int,
            options: [String],
            selectedOption: String?
        ) {
            self.id = id
            self.number = number
            self.options = options
            self.selectedOption = selectedOption
        }
    }

    public let title: String
    public let caption: String
    public let buttonTitle: String
    public let rows: [Row]
    public let isContinueEnabled: Bool
    public let isError: Bool
    public let failedAttemptCount: Int

    public init(
        title: String,
        caption: String,
        buttonTitle: String,
        rows: [Row],
        isContinueEnabled: Bool,
        isError: Bool,
        failedAttemptCount: Int
    ) {
        self.title = title
        self.caption = caption
        self.buttonTitle = buttonTitle
        self.rows = rows
        self.isContinueEnabled = isContinueEnabled
        self.isError = isError
        self.failedAttemptCount = failedAttemptCount
    }
}
