import LinkPresentation
import TKCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
public protocol OpenDappWarningPopupModuleOutput: AnyObject {
    var didTapOpen: ((_ url: URL, _ title: String) -> Void)? { get set }
}

@MainActor
protocol OpenDappWarningPopupViewModel: AnyObject {
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }

    func viewDidLoad()
}

@MainActor
final class OpenDappWarningPopupViewModelImplementation: OpenDappWarningPopupViewModel, OpenDappWarningPopupModuleOutput {
    // MARK: - State

    enum TitleState {
        case none
        case resolving(task: Task<Void, Never>)
        case resolved(title: String)

        var title: String {
            switch self {
            case .none, .resolving:
                "..."
            case let .resolved(title):
                title
            }
        }
    }

    private var titleState: TitleState = .none

    // MARK: - Dependencies

    private let url: URL
    private let appSettings: AppSettings

    init(
        url: URL,
        appSettings: AppSettings
    ) {
        self.url = url
        self.appSettings = appSettings
    }

    // MARK: - OpenDappWarningPopupModuleOutput

    var didTapOpen: ((_ url: URL, _ title: String) -> Void)?

    // MARK: - OpenDappWarningPopupViewModel

    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?

    func viewDidLoad() {
        prepareContent()

        let task = Task {
            let provider = LPMetadataProvider()
            do {
                let meta = try await provider.startFetchingMetadata(for: url)
                titleState = .resolved(title: meta.title ?? "...")
            } catch {
                titleState = .resolved(title: "...")
            }
            prepareContent()
        }
        titleState = .resolving(task: task)
    }

    private func prepareContent() {
        var isDoNotShowMarked = false

        let title = titleState.title

        var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        buttonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString("\(TKLocales.Actions.open)")
        )
        buttonConfiguration.action = { [weak self] in
            guard let self else { return }
            if let host = url.host {
                appSettings.setIsDappOpenWarningDoNotShow(host, doNotShow: isDoNotShowMarked)
            }
            didTapOpen?(url, titleState.title)
        }

        let configuration = TKPopUp.Configuration(
            items: [
                TKPopUp.Component.TitleCaption(
                    title: title,
                    caption: url.host ?? "...",
                    bottomSpace: 0
                ),
                TKPopUp.Component.GroupComponent(
                    padding: UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16),
                    items: [
                        OpenDappWarningBannerItem(
                            configuration: OpenDappWarningBannerView.Model(
                                text: TKLocales.Dapp.OpenWarningPopup.warning
                            ),
                            bottomSpace: 0
                        ),
                    ]
                ),
                TKPopUp.Component.ButtonGroupComponent(
                    buttons: [TKPopUp.Component.ButtonComponent(buttonConfiguration: buttonConfiguration)],
                    bottomSpace: 16
                ),
                TKPopUp.Component.TickItem(
                    model: TKDetailsTickView.Model(
                        text: TKLocales.Tick.doNotShowAgain,
                        tick: TKDetailsTickView.Model.Tick(
                            isSelected: isDoNotShowMarked,
                            closure: {
                                isDoNotShowMarked = $0
                            }
                        )
                    ),
                    bottomSpace: 16
                ),
            ]
        )

        didUpdateConfiguration?(configuration)
    }
}
