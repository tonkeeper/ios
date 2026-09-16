import KeeperCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class SettingsListSecurityConfigurator: SettingsListConfigurator {
    var didRequirePasscode: (() async -> String?)?
    var didTapChangePasscode: (() -> Void)?

    // MARK: - SettingsListConfigurator

    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        TKLocales.Security.title
    }

    func getInitialState() -> SettingsListState {
        createState()
    }

    // MARK: - Dependencies

    private let securityStore: SecurityStore
    private let mnemonicsAccess: MnemonicAccess
    private let biometryProvider: BiometryProvider

    // MARK: - Init

    init(
        securityStore: SecurityStore,
        mnemonicsAccess: MnemonicAccess,
        biometryProvider: BiometryProvider
    ) {
        self.securityStore = securityStore
        self.mnemonicsAccess = mnemonicsAccess
        self.biometryProvider = biometryProvider

        securityStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateIsBiometryEnabled, .didUpdateIsLockScreen:
                DispatchQueue.main.async {
                    let state = observer.createState()
                    observer.didUpdateState?(state)
                }
            case .didUpdatePasscodeBruteForce:
                break
            }
        }
    }

    private func createState() -> SettingsListState {
        SettingsListState(
            sections: [
                createBiometrySection(),
                createLockscreenSection(),
                createChangePasscodeSection(),
            ]
        )
    }

    private func createBiometrySection() -> SettingsListSection {
        .items(SettingsListItemsSection(
            items: [.listItem(createBiometryItem())],
            footer: TKLocales.Security.useBiometryDescription
        ))
    }

    private func createLockscreenSection() -> SettingsListSection {
        .items(SettingsListItemsSection(
            items: [.listItem(createLockScreenItem())],
            footer: TKLocales.Security.lockScreenDescription
        ))
    }

    private func createChangePasscodeSection() -> SettingsListSection {
        .items(SettingsListItemsSection(
            items: [.listItem(createChangePasscodeItem())]
        ))
    }

    private func createBiometryItem() -> SettingsListItem {
        let state = biometryProvider
            .getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics)
        let isOn: Bool
        let isEnabled: Bool
        let title: String
        switch state {
        case let .success(state):
            switch state {
            case .none:
                title = TKLocales.Security.unavailableError
                isEnabled = false
                isOn = false
            case .faceID:
                title = TKLocales.Security.use(String.faceId)
                isEnabled = true
                isOn = securityStore.getState().isBiometryEnable
            case .touchID:
                title = TKLocales.Security.use(String.touchId)
                isEnabled = true
                isOn = securityStore.getState().isBiometryEnable
            }
        case .failure:
            title = TKLocales.Security.unavailableError
            isEnabled = false
            isOn = false
        }

        let action: (Bool) -> Void = { [weak self] isOn in
            guard let self else { return }
            Task {
                do {
                    if isOn {
                        guard let passcode = await self.didRequirePasscode?() else {
                            await MainActor.run {
                                let state = self.createState()
                                self.didUpdateState?(state)
                            }
                            return
                        }
                        try self.mnemonicsAccess.setPasscode(passcode)
                        await self.securityStore.setIsBiometryEnable(true)
                    } else {
                        do {
                            try self.mnemonicsAccess.deletePasscode()
                            await self.securityStore.setIsBiometryEnable(false)
                        } catch {
                            Log.e("failed to delete passcode when disabling biometry due to error: \(error)")
                            await self.securityStore.setIsBiometryEnable(false)
                            throw error
                        }
                    }
                } catch {
                    await MainActor.run {
                        ToastPresenter.showToast(configuration: .failed)
                    }
                    await MainActor.run {
                        let state = self.createState()
                        self.didUpdateState?(state)
                    }
                }
            }
        }

        return SettingsListItem(
            id: .biometryItemIdentifier,
            title: SettingsListItemTitle(title),
            accessory: .toggle(
                SettingsListItemToggleAccessory(
                    isOn: isOn,
                    isEnabled: isEnabled,
                    onToggle: action
                )
            )
        )
    }

    private func createLockScreenItem() -> SettingsListItem {
        let action: (Bool) -> Void = { [weak self] isOn in
            guard let self else { return }
            Task {
                await self.securityStore.setIsLockScreen(isOn)
            }
        }

        return SettingsListItem(
            id: .locksreenItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Security.lockScreen),
            accessory: .toggle(
                SettingsListItemToggleAccessory(
                    isOn: securityStore.getState().isLockScreen,
                    onToggle: action
                )
            )
        )
    }

    private func createChangePasscodeItem() -> SettingsListItem {
        SettingsListItem(
            id: .changePasscodeItemIdentifier,
            title: SettingsListItemTitle(TKLocales.Security.changePasscode),
            accessory: .icon(.TKUIKit.Icons.Size28.lock, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                self?.didTapChangePasscode?()
            }
        )
    }
}

private extension String {
    static let biometryItemIdentifier = "BiometryItem"
    static let locksreenItemIdentifier = "LockScreenItem"
    static let changePasscodeItemIdentifier = "ChangePasscodeItem"
}

private extension String {
    static let faceId = TKLocales.SettingsListSecurityConfigurator.faceId
    static let touchId = TKLocales.SettingsListSecurityConfigurator.touchId
}
