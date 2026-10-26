import TKPerpsAPI

extension Components.Schemas.Integrator {
    static var none: Self {
        .init(
            integrator_account_index: 0,
            integrator_taker_fee: 0,
            integrator_maker_fee: 0,
            max_perps_taker_fee: 0,
            max_perps_maker_fee: 0,
            max_spot_taker_fee: 0,
            max_spot_maker_fee: 0,
            approval_ttl_ms: 0
        )
    }
}
