import BigInt
import Foundation
import KeeperCoreComponents
import KeeperCoreSensitive
import TKLogging
import TonSwift
import TonTransport
import TronSwift

public final class ImportWalletKindPreviewLoader {
    private let walletImportController: WalletImportController
    private let importedWalletTronResolver: ImportedWalletTronResolver
    private let multichainService: MultichainService
    private let chainKitService: ChainKitService
    private let walletSynchronizer: MultichainWalletSynchronizer
    private let walletAuthEphemeralKeyProvider: WalletAuthEphemeralKeyProviding
    private let ratesService: RatesService

    init(
        walletImportController: WalletImportController,
        importedWalletTronResolver: ImportedWalletTronResolver,
        multichainService: MultichainService,
        chainKitService: ChainKitService,
        walletSynchronizer: MultichainWalletSynchronizer,
        walletAuthEphemeralKeyProvider: WalletAuthEphemeralKeyProviding,
        ratesService: RatesService
    ) {
        self.walletImportController = walletImportController
        self.importedWalletTronResolver = importedWalletTronResolver
        self.multichainService = multichainService
        self.chainKitService = chainKitService
        self.walletSynchronizer = walletSynchronizer
        self.walletAuthEphemeralKeyProvider = walletAuthEphemeralKeyProvider
        self.ratesService = ratesService
    }

    public func loadPreviewsIfNeeded(
        words: [String],
        network: Network,
        currency: Currency
    ) async -> (ton: ImportWalletKindPreview, multichain: ImportWalletKindPreview)? {
        switch await importedWalletTronResolver.walletKindSelectionReason(
            words: words,
            network: network
        ) {
        case let .ambiguousMnemonic(legacyTronBalance):
            return await loadPreviews(
                words: words,
                tonDerivationType: .ton,
                legacyTronBalance: legacyTronBalance,
                network: network,
                currency: currency
            )
        case let .legacyTronBalance(balance):
            return await loadPreviews(
                words: words,
                tonDerivationType: .bip39,
                legacyTronBalance: balance,
                network: network,
                currency: currency
            )
        case nil:
            return nil
        }
    }
}

private extension ImportWalletKindPreviewLoader {
    func loadPreviews(
        words: [String],
        tonDerivationType: DerivationType,
        legacyTronBalance: TronBalance?,
        network: Network,
        currency: Currency
    ) async -> (ton: ImportWalletKindPreview, multichain: ImportWalletKindPreview) {
        async let tonPreview = loadPreview(
            words: words,
            type: tonDerivationType,
            legacyTronBalance: legacyTronBalance,
            network: network,
            currency: currency
        )
        async let multichainPreview = loadMultichainPreview(words: words, network: network, currency: currency)
        return await(tonPreview, multichainPreview)
    }

    func loadPreview(
        words: [String],
        type: DerivationType,
        legacyTronBalance: TronBalance?,
        network: Network,
        currency: Currency
    ) async -> ImportWalletKindPreview {
        let mnemonic = CoreMnemonic(mnemonicWords: words, type: type)
        let activeWallets = (try? await walletImportController.findActiveWallets(
            mnemonic: mnemonic,
            network: network,
            checkHistory: false
        )) ?? []

        let rates = try? await ratesService.loadRates(jettons: [], currencies: [currency])
        let tonRate = rates?.ton.first(where: { $0.currency == currency })
        let usdtRate = rates?.usdt.first(where: { $0.currency == currency })
        let rateConverter = RateConverter()

        var fiatTotal: Decimal = 0
        var nftsCount = 0

        for wallet in activeWallets {
            nftsCount += wallet.nfts.count

            if let tonRate {
                fiatTotal += rateConverter.convertToDecimal(
                    amount: BigUInt(integerLiteral: UInt64(max(wallet.balance.tonBalance.amount, 0))),
                    amountFractionLength: TonInfo.fractionDigits,
                    rate: tonRate
                )
            }

            for jettonBalance in wallet.balance.jettonsBalance {
                guard !jettonBalance.quantity.isZero,
                      jettonBalance.item.jettonInfo.verification != .blacklist,
                      let rate = jettonBalance.rates[currency]
                else {
                    continue
                }
                fiatTotal += rateConverter.convertToDecimal(
                    amount: jettonBalance.quantity,
                    amountFractionLength: jettonBalance.item.jettonInfo.fractionDigits,
                    rate: rate
                )
            }
        }

        if let legacyTronBalance, let usdtRate {
            fiatTotal += rateConverter.convertToDecimal(
                amount: legacyTronBalance.amount,
                amountFractionLength: TronSwift.USDT.fractionDigits,
                rate: usdtRate
            )
        }

        return ImportWalletKindPreview(
            fiatTotal: fiatTotal,
            nftsCount: nftsCount,
            hasActivity: legacyTronBalance != nil || fiatTotal > 0 || nftsCount > 0
        )
    }

    func loadMultichainPreview(
        words: [String],
        network: Network,
        currency: Currency
    ) async -> ImportWalletKindPreview {
        guard network == .mainnet else {
            return .empty
        }

        let phrase = words.joined(separator: " ")
        let state: MultichainWalletState
        do {
            state = try chainKitService.makeWalletState(mnemonic: phrase)
        } catch {
            Log.w("Multichain: failed to make wallet state for import preview: \(error)")
            return .empty
        }

        return await walletAuthEphemeralKeyProvider.withEphemeralKey(
            walletId: state.walletId,
            mnemonic: phrase
        ) { [self] in
            await loadMultichainPreview(
                words: words,
                phrase: phrase,
                state: state,
                network: network,
                currency: currency
            )
        }
    }

    func loadMultichainPreview(
        words: [String],
        phrase: String,
        state: MultichainWalletState,
        network: Network,
        currency: Currency
    ) async -> ImportWalletKindPreview {
        do {
            _ = try await walletSynchronizer.sync(mnemonic: phrase, state: state)
        } catch {
            Log.w("Multichain: failed to sync wallet for import preview: \(error)")
        }

        var currencyCodes = [currency.code.lowercased()]
        if currency != .defaultCurrency {
            currencyCodes.append(Currency.defaultCurrency.code.lowercased())
        }

        let fiatTotal: Decimal
        do {
            let page = try await multichainService.getAllWalletAssets(
                state: state,
                currencies: currencyCodes,
                capabilities: nil,
                chain: nil,
                search: nil,
                availableOnly: nil,
                showHidden: false,
                hideDust: nil
            )
            fiatTotal = portfolioFiatTotal(from: page.fiatPrice, currency: currency) ?? 0
        } catch {
            Log.w("Multichain: failed to load wallet assets for import preview: \(error)")
            fiatTotal = 0
        }

        let tonChainPreview = await loadPreview(
            words: words,
            type: .bip39,
            legacyTronBalance: nil,
            network: network,
            currency: currency
        )
        let resolvedFiatTotal = fiatTotal > 0 ? fiatTotal : tonChainPreview.fiatTotal
        return ImportWalletKindPreview(
            fiatTotal: resolvedFiatTotal,
            nftsCount: tonChainPreview.nftsCount
        )
    }

    func portfolioFiatTotal(from map: [String: String], currency: Currency) -> Decimal? {
        if let amount = fiatDecimal(from: map, currencyCode: currency.code) {
            return amount
        }
        if currency != .defaultCurrency,
           let amount = fiatDecimal(from: map, currencyCode: Currency.defaultCurrency.code)
        {
            return amount
        }
        return nil
    }

    func fiatDecimal(from map: [String: String], currencyCode: String) -> Decimal? {
        guard let raw = valueForCodeVariants(in: map, code: currencyCode)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty,
            let value = Decimal(string: raw)
        else {
            return nil
        }
        return value
    }

    func valueForCodeVariants(in map: [String: String], code: String) -> String? {
        for key in [code, code.uppercased(), code.lowercased()] {
            if let value = map[key] {
                return value
            }
        }
        return map.first { $0.key.caseInsensitiveCompare(code) == .orderedSame }?.value
    }
}
