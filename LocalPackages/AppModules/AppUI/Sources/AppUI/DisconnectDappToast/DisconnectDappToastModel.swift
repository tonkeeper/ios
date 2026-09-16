import Foundation

public struct DisconnectDappToastModel {
    public let title: String
    public let buttonTitle: String
    public let buttonAction: () -> Void

    public init(
        title: String,
        buttonTitle: String,
        buttonAction: @escaping () -> Void
    ) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }
}
