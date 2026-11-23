import Foundation
import TKLocalize

/// What every Live Activity presentation shows for a state, so the Lock Screen, the expanded and the
/// compact Dynamic Island tell the same story. Compiled into the widget extension too.
@available(iOS 16.1, *)
struct TransactionLiveActivityPresentation: Equatable {
    typealias State = TransactionLiveActivityAttributes.ContentState

    /// A pending activity with no update for this long turns stale.
    static let staleInterval: TimeInterval = 5 * 60
    static let hiddenAmount = "* * *"

    /// Drawn instead of the token logo when the app had none to share.
    enum Glyph: Equatable {
        case send
        case receive
        case swap
        case perps
        case pending
    }

    enum Badge: Equatable {
        case arrowUp
        case arrowDown
        case swap
        case trayArrowDown
        case trayArrowUp
        case clock
        case done
        case cross
        case question
    }

    enum Tone: Equatable {
        case pending
        case success
        case failure
        case warning
        case neutral
    }

    struct Amount: Equatable {
        enum Style: Equatable {
            case primary
            case positive
            case secondary
        }

        let text: String
        let style: Style
    }

    struct Progress: Equatable {
        let steps: Int
        /// How many steps are filled, from 0 to `steps`; the current step is filled by half.
        let filled: Double
        let tone: Tone

        var fraction: Double {
            filled / Double(steps)
        }
    }

    let status: String
    let statusTone: Tone
    let glyph: Glyph
    let badge: Badge
    let badgeTone: Tone
    let title: String
    let subtitle: String?
    let amount: Amount?
    let secondaryAmount: Amount?
    /// From the most to the least detailed: the compact island shows the first that fits.
    let compactValues: [String]
    let progress: Progress
    let icon: String?
    let queuedCount: Int

    /// `counterparty` names the other side of a transfer from its full address; `nil` leaves it unnamed.
    init(
        state: State,
        isStale: Bool,
        counterparty: (String) -> String? = TransactionLiveActivityCounterparties.shortened
    ) {
        let isStale = isStale && state.status == .pending
        title = state.title
        icon = state.icon
        queuedCount = state.status == .pending ? max(0, state.queuedCount ?? 0) : 0
        glyph = switch state.kind {
        case .send: .send
        case .receive: .receive
        case .swap: .swap
        case .deposit, .withdrawal, .open, .close: .perps
        case .other, nil: state.chain == "PERPS" ? .perps : .pending
        }

        switch state.status {
        case .pending where isStale:
            status = TKLocales.LiveActivity.noUpdatesFor(Int(Self.staleInterval / 60))
            statusTone = .warning
            badge = .clock
            badgeTone = .warning
        case .pending:
            status = state.stage?.title ?? TKLocales.LiveActivity.confirming
            statusTone = .neutral
            badge = Self.badge(for: state.kind)
            badgeTone = .pending
        case .confirmed:
            status = TKLocales.LiveActivity.confirmed
            statusTone = .success
            badge = .done
            badgeTone = .success
        case .failed, .dropped:
            status = TKLocales.State.failed
            statusTone = .failure
            badge = .cross
            badgeTone = .failure
        case .unknown:
            status = TKLocales.LiveActivity.updatedAt(state.updatedAt.formatted(date: .omitted, time: .shortened))
            statusTone = .neutral
            badge = .question
            badgeTone = .neutral
        }

        let steps = max(1, state.steps ?? state.stage?.count ?? 1)
        progress = switch state.status {
        case .pending:
            Progress(
                steps: steps,
                filled: Double(min(max(state.stage?.index ?? 1, 1), steps)) - 0.5,
                tone: isStale ? .warning : .pending
            )
        case .confirmed: Progress(steps: steps, filled: Double(steps), tone: .success)
        case .failed, .dropped: Progress(steps: steps, filled: Double(steps), tone: .failure)
        case .unknown: Progress(steps: steps, filled: 0, tone: .neutral)
        }

        let source = state.source.flatMap { $0.amount.nonEmpty == nil ? nil : $0 }
        let destination = state.destination.flatMap { $0.amount.nonEmpty == nil ? nil : $0 }
        let isExchange = switch state.kind {
        case .swap, .deposit: true
        case .other, nil: source != nil && destination != nil
        case .send, .receive, .withdrawal, .open, .close: false
        }
        let primaryLeg: State.Leg? = switch state.kind {
        case .send: source ?? destination
        default: destination ?? source
        }
        let amounts = Self.amounts(
            state: state,
            primaryLeg: primaryLeg,
            source: source,
            isExchange: isExchange
        )
        amount = amounts.amount
        secondaryAmount = amounts.secondary

        if state.isRedacted {
            compactValues = [Self.hiddenAmount]
        } else {
            let fallback: String = (state.destination?.currency.nonEmpty ?? state.source?.currency.nonEmpty)
                ?? (state.destination?.network.nonEmpty ?? state.source?.network.nonEmpty)
                ?? state.chain
            let currency = primaryLeg?.currency.nonEmpty
            let detailed: [String?] = amounts.amount.map { amount in
                let number = currency.map { amount.text.hasSuffix(" \($0)") ? String(amount.text.dropLast($0.count + 1)) : amount.text }
                return [amount.text, number, currency]
            } ?? []
            var compactValues: [String] = []
            for value in detailed.compactMap({ $0 }) + [fallback] where !compactValues.contains(value) {
                compactValues.append(value)
            }
            self.compactValues = compactValues
        }

        subtitle = Self.subtitle(state: state, counterparty: counterparty, isExchange: isExchange)
    }

    private static func badge(for kind: State.Kind?) -> Badge {
        switch kind {
        case .send, .open: .arrowUp
        case .receive, .close: .arrowDown
        case .swap: .swap
        case .deposit: .trayArrowDown
        case .withdrawal: .trayArrowUp
        case .other, nil: .clock
        }
    }

    private static func amounts(
        state: State,
        primaryLeg: State.Leg?,
        source: State.Leg?,
        isExchange: Bool
    ) -> (amount: Amount?, secondary: Amount?) {
        guard !state.isRedacted else {
            return (Amount(text: hiddenAmount, style: .primary), nil)
        }
        let moved = state.status == .pending || state.status == .confirmed
        let unsigned = state.status == .unknown
        let outgoing = unsigned ? "" : "\u{2212}"
        let fiat = state.fiat.nonEmpty.map { Amount(text: $0, style: .secondary) }
        switch state.kind {
        case .send:
            return (amount(primaryLeg, sign: outgoing, style: moved || unsigned ? .primary : .secondary), fiat)
        case .receive, .withdrawal:
            return (amount(primaryLeg, sign: moved ? "+" : "", style: moved ? .positive : .primary), fiat)
        case .open, .close:
            return (amount(primaryLeg, sign: "", style: .primary), fiat)
        case .swap, .deposit, .other, nil:
            guard isExchange, let source, source != primaryLeg else {
                return (amount(primaryLeg, sign: "", style: .primary), fiat)
            }
            let style: Amount.Style = unsigned ? .primary : moved ? .positive : .secondary
            return (
                amount(primaryLeg, sign: unsigned ? "" : "+", style: style),
                amount(source, sign: outgoing, style: .secondary)
            )
        }
    }

    private static func subtitle(
        state: State,
        counterparty: (String) -> String?,
        isExchange: Bool
    ) -> String? {
        switch state.status {
        case .unknown: return TKLocales.LiveActivity.checkStatusInHistory
        case .dropped: return TKLocales.LiveActivity.droppedByNetwork
        case .pending, .confirmed, .failed: break
        }
        let detail = state.detail.nonEmpty
        switch state.kind {
        case .send, .receive:
            let isSend = state.kind == .send
            let leg = isSend ? state.source ?? state.destination : state.destination ?? state.source
            let network = leg?.network.nonEmpty.flatMap { isNative(leg?.currency, on: $0) ? nil : $0 }
            let party = state.isRedacted ? hiddenAmount : state.counterpartyAddress.nonEmpty.flatMap(counterparty)
            guard let party else { return network.map(networkName) ?? detail }
            let side = isSend ? TKLocales.LiveActivity.to(party) : TKLocales.LiveActivity.from(party)
            return network.map { TKLocales.LiveActivity.onNetwork(side, networkName($0)) } ?? side
        case .open, .close:
            return TKLocales.LiveActivity.perps
        case .swap, .deposit, .withdrawal, .other, nil:
            if state.kind != .withdrawal,
               let from = state.source?.currency.nonEmpty,
               let to = state.destination?.currency.nonEmpty,
               from != to
            {
                return "\(from) → \(to)"
            }
            if let from = state.source?.network.nonEmpty,
               let to = state.destination?.network.nonEmpty,
               from != to
            {
                return "\(networkName(from)) → \(networkName(to))"
            }
            return isExchange ? nil : detail
        }
    }

    /// A chain's own coin needs no network next to it; a token that lives on several chains does.
    private static func isNative(_ currency: String?, on network: String) -> Bool {
        guard let currency else { return false }
        let native: Set<String> = switch network {
        case "TON": ["GRAM", "TON"]
        case "TRON": ["TRX"]
        case "ETH", "BASE", "ARB": ["ETH"]
        case "BSC": ["BNB"]
        case "POLYGON": ["POL", "MATIC"]
        default: [network]
        }
        return native.contains(currency)
    }

    private static func networkName(_ network: String) -> String {
        typealias Networks = TKLocales.Receive.Multichain.Networks
        return switch network {
        case "PERPS": TKLocales.LiveActivity.perps
        case "TON": Networks.Ton.title
        case "ETH": Networks.Ethereum.title
        case "BTC": Networks.Bitcoin.title
        case "BASE": Networks.Base.title
        case "BSC": Networks.Smartchain.title
        case "ARB": Networks.Arbitrum.title
        case "TRON": Networks.Tron.title
        case "SOL": Networks.Solana.title
        case "POLYGON": Networks.Polygon.title
        case "AVAX": Networks.Avalanche.title
        case "ROBINHOOD": Networks.Robinhood.title
        default: network
        }
    }

    private static func amount(_ leg: State.Leg?, sign: String, style: Amount.Style) -> Amount? {
        guard let leg, let value = leg.amount.nonEmpty else { return nil }
        let text = [sign + value, leg.currency.nonEmpty].compactMap { $0 }.joined(separator: " ")
        return Amount(text: text, style: style)
    }
}

private extension String? {
    var nonEmpty: String? {
        flatMap(\.nonEmpty)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
