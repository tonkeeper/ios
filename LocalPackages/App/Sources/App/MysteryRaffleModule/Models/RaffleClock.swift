import Foundation
import TKFeatureFlags

/// The instant every client-side raffle derivation compares against.
///
/// The raffle's phase is split between the two sides: the backend resolves copy and
/// `status` against the request's `_debug_now`, while the client derives the layout
/// (migration / active, countdowns, entry-point visibility) from `starts_at` /
/// `ends_at` / `zero_fee_ends_at`. Reading real time here would make the two disagree as
/// soon as QA shifts the clock — the backend answers with week-1 content and the client
/// renders the post-migration layout for it. Real time in production, where the override
/// is dev-menu-only and always nil.
enum RaffleClock {
    private static let appSettings: TKAppSettings = UserDefaultsTKAppSettings()

    static var now: Date {
        now(Date())
    }

    /// Same override applied to an externally supplied instant — e.g. a `TimelineView`
    /// tick, which would otherwise keep ticking in real time under a shifted clock.
    static func now(_ realNow: Date) -> Date {
        appSettings.raffleDebugNow ?? realNow
    }
}
