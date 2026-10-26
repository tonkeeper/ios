import Foundation

/// What every Live Activity presentation shows for a state, so the Lock Screen, the expanded and the
/// compact Dynamic Island tell the same story. Compiled into the widget extension too.
@available(iOS 16.1, *)
struct TransactionLiveActivityPresentation: Equatable {
    typealias State = TransactionLiveActivityAttributes.ContentState

    enum Glyph: Equatable {
        case send
        case receive
        case swap
        case perps
        case pending
        case confirmed
        case failed
        case unknown
    }

    enum Tone: Equatable {
        case pending
        case success
        case failure
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

    let glyph: Glyph
    let tone: Tone
    let title: String
    let subtitle: String?
    let amount: Amount?
    let secondaryAmount: Amount?
    /// From the most to the least detailed: the compact island shows the first that fits.
    let compactValues: [String]
    let showsStaleNotice: Bool
    /// The share of a multi-stage operation's stages reached, drawn as a ring around the glyph.
    let progress: Double?

    /// `counterparty` names the other side of a transfer from its full address; `nil` leaves it unnamed.
    init(
        state: State,
        isStale: Bool,
        counterparty: (String) -> String? = TransactionLiveActivityCounterparties.shortened
    ) {
        switch state.status {
        case .pending:
            tone = .pending
            glyph = switch state.kind {
            case .send: .send
            case .receive: .receive
            case .swap: .swap
            case .other, nil: state.chain == "PERPS" ? .perps : .pending
            }
        case .confirmed:
            tone = .success
            glyph = .confirmed
        case .failed, .dropped:
            tone = .failure
            glyph = .failed
        case .unknown:
            tone = .neutral
            glyph = .unknown
        }
        title = state.title
        showsStaleNotice = isStale && state.status == .pending
        progress = state.status == .pending
            ? state.stage.map { min(1, max(0, Double($0.index) / Double(max($0.count, 1)))) }
            : nil

        let hasMoved = state.status == .pending || state.status == .confirmed
        let directionSign = state.status == .unknown ? "" : "+"
        let outgoingSign = state.status == .unknown ? "" : "\u{2212}"
        let source = state.source.flatMap { $0.amount.nonEmpty == nil ? nil : $0 }
        let destination = state.destination.flatMap { $0.amount.nonEmpty == nil ? nil : $0 }
        let primaryLeg: State.Leg?
        switch state.kind {
        case .send:
            primaryLeg = source ?? destination
            amount = Self.makeAmount(primaryLeg, sign: outgoingSign, style: hasMoved ? .primary : .secondary)
            secondaryAmount = nil
        case .receive:
            primaryLeg = destination ?? source
            amount = Self.makeAmount(primaryLeg, sign: directionSign, style: hasMoved ? .positive : .secondary)
            secondaryAmount = nil
        case .swap, .other, nil:
            if let source, let destination {
                primaryLeg = destination
                amount = Self.makeAmount(destination, sign: directionSign, style: hasMoved ? .positive : .secondary)
                secondaryAmount = Self.makeAmount(source, sign: outgoingSign, style: .secondary)
            } else {
                primaryLeg = destination ?? source
                amount = Self.makeAmount(primaryLeg, sign: "", style: hasMoved ? .primary : .secondary)
                secondaryAmount = nil
            }
        }

        let fallback: String = (state.destination?.currency.nonEmpty ?? state.source?.currency.nonEmpty)
            ?? (state.destination?.network.nonEmpty ?? state.source?.network.nonEmpty)
            ?? state.chain
        let detailed: [String?] = primaryLeg.flatMap { leg in
            Self.label(leg, sign: "").map { [$0, leg.amount.nonEmpty, leg.currency.nonEmpty] }
        } ?? []
        var compactValues: [String] = []
        for value in detailed.compactMap({ $0 }) + [fallback] where !compactValues.contains(value) {
            compactValues.append(value)
        }
        self.compactValues = compactValues

        let detail = state.detail.nonEmpty.flatMap { $0 == primaryLeg?.currency ? nil : $0 }
        switch state.kind {
        case .send, .receive:
            let leg = state.kind == .send
                ? state.source ?? state.destination
                : state.destination ?? state.source
            let network = leg?.network.nonEmpty.flatMap { $0 == leg?.currency ? nil : $0 }
            subtitle = [network, state.counterpartyAddress.nonEmpty.flatMap(counterparty)]
                .compactMap { $0 }
                .joined(separator: " · ")
                .nonEmpty ?? detail
        case .swap, .other, nil:
            if let from = state.source?.network.nonEmpty,
               let to = state.destination?.network.nonEmpty,
               from != to
            {
                subtitle = "\(from) → \(to)"
            } else {
                subtitle = state.kind == .swap ? nil : detail
            }
        }
    }

    private static func makeAmount(_ leg: State.Leg?, sign: String, style: Amount.Style) -> Amount? {
        leg.flatMap { label($0, sign: sign) }.map { Amount(text: $0, style: style) }
    }

    private static func label(_ leg: State.Leg, sign: String) -> String? {
        guard let amount = leg.amount.nonEmpty else { return nil }
        return [sign + amount, leg.currency.nonEmpty].compactMap { $0 }.joined(separator: " ")
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
