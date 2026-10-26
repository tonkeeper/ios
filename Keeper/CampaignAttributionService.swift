import BranchSDK
import Foundation
import LinkrunnerKit
import TKCore
import TKLogging
import UIKit

@MainActor
final class CampaignAttributionService {
    static let shared = CampaignAttributionService()

    private let store: CampaignAttributionStore
    private var buffer = ResolvedDeeplinkBuffer()
    private var onResolvedDeeplink: ((String) -> Void)?
    private var didStart = false
    private var branchEnabled = false
    private var linkrunnerEnabled = false
    private var linkrunnerReady = false
    private var pendingLinkrunnerURLs: [String] = []

    init(store: CampaignAttributionStore = .shared) {
        self.store = store
    }

    func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !didStart else { return }
        didStart = true
        startBranch(launchOptions: launchOptions)
        startLinkrunner()
    }

    func noteDelivered(_ link: String?) {
        buffer.markDelivered(link)
    }

    func beginForwarding() {
        buffer.beginCoalescing()
    }

    func finishForwarding() {
        route(buffer.endCoalescing())
    }

    func attachRouter(_ router: @escaping (String) -> Void) {
        onResolvedDeeplink = router
        route(buffer.attachRouter())
    }

    func forwardColdStart(scene: UIScene, connectionOptions: UIScene.ConnectionOptions) {
        if branchEnabled {
            if let userActivity = connectionOptions.userActivities.first {
                BranchScene.shared().scene(scene, continue: userActivity)
            } else if !connectionOptions.urlContexts.isEmpty {
                BranchScene.shared().scene(scene, openURLContexts: connectionOptions.urlContexts)
            }
        }

        for activity in connectionOptions.userActivities {
            if let url = activity.webpageURL?.absoluteString {
                forwardToLinkrunner(url)
            }
        }
        for context in connectionOptions.urlContexts {
            forwardToLinkrunner(context.url.absoluteString)
        }
    }

    func forwardUniversalLink(scene: UIScene, userActivity: NSUserActivity) {
        if branchEnabled {
            BranchScene.shared().scene(scene, continue: userActivity)
        }
        if let url = userActivity.webpageURL?.absoluteString {
            forwardToLinkrunner(url)
        }
    }

    func forwardCustomScheme(scene: UIScene, urlContexts: Set<UIOpenURLContext>) {
        if branchEnabled {
            BranchScene.shared().scene(scene, openURLContexts: urlContexts)
        }
        urlContexts.forEach { forwardToLinkrunner($0.url.absoluteString) }
    }

    private func startBranch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        let liveKey = CampaignAttributionCredentials.configured(infoValue("BRANCH_KEY_LIVE"))
        let testKey = CampaignAttributionCredentials.configured(infoValue("BRANCH_KEY_TEST"))
        guard liveKey != nil || testKey != nil else {
            Log.i("Branch attribution is disabled until BRANCH_KEY_LIVE or BRANCH_KEY_TEST is set")
            return
        }
        if liveKey == nil {
            Branch.setUseTestBranchKey(true)
            Log.i("Branch attribution is using the test key")
        }
        branchEnabled = true
        #if DEBUG
            Branch.enableLogging()
        #endif
        Branch.getInstance().initSession(launchOptions: launchOptions) { [weak self] params, error in
            Task { @MainActor in
                await self?.handleBranchSession(params: params, error: error)
            }
        }
    }

    private func startLinkrunner() {
        guard let token = CampaignAttributionCredentials.configured(infoValue("LINKRUNNER_TOKEN")) else {
            Log.i("Linkrunner attribution is disabled until LINKRUNNER_TOKEN is set")
            return
        }
        linkrunnerEnabled = true
        Task { [weak self] in
            guard let self else { return }
            // The SDK requests tracking authorization while collecting IDFA, and this app
            // has no usage description for that prompt. Deferred matching does not need IDFA.
            await LinkrunnerSDK.shared.initialize(
                token: token,
                disableIdfa: true,
                debug: Self.linkrunnerDebug
            )
            linkrunnerReady = true
            await captureLinkrunnerAttribution()
            let queued = pendingLinkrunnerURLs
            pendingLinkrunnerURLs.removeAll()
            for url in queued {
                await handleLinkrunnerDeeplink(url)
            }
        }
    }

    private func forwardToLinkrunner(_ url: String) {
        guard linkrunnerEnabled else { return }
        if linkrunnerReady {
            Task { [weak self] in
                await self?.handleLinkrunnerDeeplink(url)
            }
        } else {
            pendingLinkrunnerURLs.append(url)
        }
    }

    private func handleBranchSession(params: [AnyHashable: Any]?, error: Error?) async {
        if let error {
            Log.w("Branch session failed", error: error)
        }
        guard let params else { return }
        let payload = AttributionObjectBridge.object(from: params)
        var stored = false
        if let record = CampaignAttributionDecoding.makeRecord(
            provider: .branch,
            payload: payload,
            capturedAt: Date()
        ) {
            stored = await store.capture(record)
        }
        guard CampaignAttributionDecoding.shouldRoute(
            provider: .branch,
            payload: payload,
            isFirstTouch: stored
        ) else { return }
        route(CampaignAttributionDecoding.branchDestination(payload))
    }

    private func handleLinkrunnerDeeplink(_ url: String) async {
        let response = await LinkrunnerSDK.shared.handleDeeplink(url: url)
        await captureLinkrunnerAttribution()
        guard response.isLinkrunner, let deeplink = response.deeplink else { return }
        if await store.record(for: .linkrunner) == nil {
            let payload: [String: AttributionJSON] = [
                "attributionSource": .string("deeplink"),
                "deeplink": .string(deeplink),
                "isLinkrunner": .bool(true),
            ]
            if let record = CampaignAttributionDecoding.makeRecord(
                provider: .linkrunner,
                payload: payload,
                capturedAt: Date()
            ) {
                _ = await store.capture(record)
            }
        }
        route(CampaignAttributionDecoding.linkrunnerDestination(["deeplink": .string(deeplink)]))
    }

    private func captureLinkrunnerAttribution() async {
        let attribution = await LinkrunnerSDK.shared.getAttributionData()
        let payload = LinkrunnerAttributionPayload.make(attribution)
        guard let record = CampaignAttributionDecoding.makeRecord(
            provider: .linkrunner,
            payload: payload,
            capturedAt: Date()
        ) else { return }
        let stored = await store.capture(record)
        guard CampaignAttributionDecoding.shouldRoute(
            provider: .linkrunner,
            payload: payload,
            isFirstTouch: stored
        ) else { return }
        route(record.resolvedDeeplink)
    }

    private func route(_ link: String?) {
        route(buffer.receive(link))
    }

    private func route(_ links: [String]) {
        guard let onResolvedDeeplink else { return }
        for link in links {
            onResolvedDeeplink(link)
        }
    }

    private func infoValue(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private static var linkrunnerDebug: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
}

private enum AttributionObjectBridge {
    static func object(from dictionary: [AnyHashable: Any]) -> [String: AttributionJSON] {
        var payload: [String: AttributionJSON] = [:]
        for (key, value) in dictionary {
            guard let key = key as? String else { continue }
            payload[key] = json(from: value)
        }
        return payload
    }

    private static func json(from value: Any) -> AttributionJSON {
        if value is NSNull {
            return .null
        }
        if let string = value as? String {
            return .string(string)
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        }
        if let dictionary = value as? [AnyHashable: Any] {
            return .object(object(from: dictionary))
        }
        if let array = value as? [Any] {
            return .array(array.map(json(from:)))
        }
        return .string(String(describing: value))
    }
}

private enum LinkrunnerAttributionPayload {
    static func make(_ attribution: LRAttributionDataResponse) -> [String: AttributionJSON] {
        var payload: [String: AttributionJSON] = [
            "attributionSource": .string(attribution.attributionSource),
        ]
        if let deeplink = attribution.deeplink {
            payload["deeplink"] = .string(deeplink)
        }
        guard let campaign = attribution.campaignData else { return payload }
        var campaignData: [String: AttributionJSON] = [
            "id": .string(campaign.id),
            "name": .string(campaign.name),
            "type": .string(campaign.type.rawValue),
        ]
        let fields = [
            "adNetwork": campaign.adNetwork?.rawValue,
            "groupName": campaign.groupName,
            "adNetworkCampaignId": campaign.adNetworkCampaignId,
            "adSetId": campaign.adSetId,
            "adSetName": campaign.adSetName,
            "adCreativeId": campaign.adCreativeId,
            "adCreativeName": campaign.adCreativeName,
            "assetName": campaign.assetName,
        ]
        for (key, value) in fields {
            guard let value else { continue }
            campaignData[key] = .string(value)
        }
        payload["campaignData"] = .object(campaignData)
        return payload
    }
}
