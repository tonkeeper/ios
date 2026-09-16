import Foundation
import MultichainAPI

extension MultichainRaffleStatus {
    init(api: MultichainAPI.Components.Schemas.RaffleStatus) {
        switch api {
        case .not_joined: self = .notJoined
        case .joined: self = .joined
        case .ended_pending: self = .endedPending
        case .won: self = .won
        case .lost: self = .lost
        }
    }
}

extension MultichainRaffleHero {
    init(api: MultichainAPI.Components.Schemas.RaffleHero) {
        self.init(image: api.image, badgeIconId: api.badge_icon_id)
    }
}

extension MultichainRaffleCompactBanner {
    init(api: MultichainAPI.Components.Schemas.RaffleCompactBanner) {
        self.init(
            defaultTitle: api.default_title,
            activeTitle: api.active_title,
            iconId: api.icon_id
        )
    }
}

extension MultichainRaffleBanner {
    init(api: MultichainAPI.Components.Schemas.RaffleBanner) {
        self.init(
            title: api.title,
            description: api.description,
            imageURL: api.image_url,
            button: MultichainRaffleCTA(api: api.button)
        )
    }
}

extension MultichainRaffleBenefitCard {
    init(api: MultichainAPI.Components.Schemas.RaffleBenefitCard) {
        self.init(
            id: api.id,
            iconId: api.icon_id,
            label: api.label,
            title: api.title,
            subtitle: api.subtitle,
            imageURL: api.image_url
        )
    }
}

extension MultichainRafflePrize {
    init(api: MultichainAPI.Components.Schemas.RafflePrize) {
        self.init(
            id: api.id,
            image: api.image,
            title: api.title,
            subtitle: api.subtitle
        )
    }
}

extension MultichainRaffleTask {
    init(api: MultichainAPI.Components.Schemas.RaffleTask) {
        self.init(
            id: api.id,
            iconId: api.icon_id,
            title: api.title,
            subtitle: api.subtitle,
            rewardTickets: api.reward_tickets,
            deeplink: api.deeplink,
            done: api.done
        )
    }
}

extension MultichainRaffleMilestone {
    init(api: MultichainAPI.Components.Schemas.RaffleMilestone) {
        self.init(
            id: api.id,
            iconId: api.icon_id,
            title: api.title,
            subtitle: api.subtitle,
            rewardTickets: api.reward_tickets,
            done: api.done
        )
    }
}

extension MultichainRaffleCTA {
    init(api: MultichainAPI.Components.Schemas.RaffleCTA) {
        let action: Action
        switch api.action {
        case .deeplink: action = .deeplink
        case .link: action = .link
        }
        self.init(title: api.title, action: action, payload: api.payload)
    }
}

extension MultichainRaffleStory {
    init(api: MultichainAPI.Components.Schemas.RaffleStory) {
        self.init(
            id: api.id,
            pages: api.pages.map { MultichainRaffleStoryPage(api: $0) }
        )
    }
}

extension MultichainRaffleStoryPage {
    init(api: MultichainAPI.Components.Schemas.RaffleStoryPage) {
        self.init(
            title: api.title,
            description: api.description,
            image: api.image,
            buttons: (api.buttons ?? []).map { MultichainRaffleCTA(api: $0) }
        )
    }
}

extension MultichainRaffleHistoryItem {
    init(api: MultichainAPI.Components.Schemas.RaffleHistoryItem) {
        self.init(
            id: api.id,
            awardedAt: api.awarded_at,
            iconId: api.icon_id,
            title: api.title,
            tickets: api.tickets
        )
    }
}

extension MultichainRaffleWinningPrize {
    init(api: MultichainAPI.Components.Schemas.RaffleWinningPrize) {
        self.init(title: api.title, image: api.image)
    }
}

extension MultichainRaffleProgress {
    init(api: MultichainAPI.Components.Schemas.RaffleProgress) {
        self.init(
            ticketsTotal: api.tickets_total,
            history: api.history.map { MultichainRaffleHistoryItem(api: $0) },
            winningPrize: api.winning_prize.map { MultichainRaffleWinningPrize(api: $0) },
            prizeDeliveryDays: api.prize_delivery_days,
            zeroFeeEndsAt: api.zero_fee_ends_at
        )
    }
}

extension MultichainRaffle {
    init(api: MultichainAPI.Components.Schemas.Raffle) {
        self.init(
            id: api.id,
            status: MultichainRaffleStatus(api: api.status),
            hero: MultichainRaffleHero(api: api.hero),
            title: api.title,
            subtitle: api.subtitle,
            startsAt: api.starts_at,
            endsAt: api.ends_at,
            prizesRevealAt: api.prizes_reveal_at,
            compactBanner: MultichainRaffleCompactBanner(api: api.compact_banner),
            prizesHeader: api.prizes_header,
            statusBadge: api.status_badge,
            benefitCards: (api.benefit_cards ?? []).map { MultichainRaffleBenefitCard(api: $0) },
            prizes: api.prizes.map { MultichainRafflePrize(api: $0) },
            tasks: api.tasks.map { MultichainRaffleTask(api: $0) },
            milestones: api.milestones.map { MultichainRaffleMilestone(api: $0) },
            cta: MultichainRaffleCTA(api: api.cta),
            progress: api.progress.map { MultichainRaffleProgress(api: $0) },
            banner: api.banner.map { MultichainRaffleBanner(api: $0) },
            stories: (api.stories ?? []).map { MultichainRaffleStory(api: $0) }
        )
    }
}
