# Perps operation diagnostics

Deposit, withdrawal and trading events use the `Perps` category and `Operation` message.
The shared fields are `flow`, `stage`, `outcome`, `trace_id`, `wallet_id`,
`asset_id`, `chain`, and `amount` (whole tokens) / `amount_units` (base units).
Stages add quote / execution / deposit / operation IDs, account index, fees,
expiry, transaction hashes and elapsed milliseconds when available.

Start with the first `failed`, `rejected`, `unavailable` or `unknown` event.
Follow its `trace_id` through preparation, quote and confirmation. Once a
payment is saved, follow `operation_id` through journal transitions and recovery;
recovery survives app restarts, so it does not retain an in-memory trace ID.
HTTP logs carry the same context, status and server request ID even for fast
successful operation requests. Unchanged status polls remain quiet.

`boundary` identifies the stage's dependency; `source` classifies a recognized
failure: `client`, `wallet`, `backend`, `lighter`, `chain_rpc`, `network`, or
`user_or_lifecycle`. `wallet_or_backend`, `lighter_or_backend`, `backend_or_client_contract`, and
`unknown` deliberately preserve uncertainty. A backend response without a more
specific machine reason is attributed to the backend boundary, not proof that
its implementation is at fault. Backend `http_status`, `code`, `reason` and
`retryable` are separate fields. A timeout cannot prove whether a transfer was
accepted: the submit event and subsequent durable state retain `unknown`.

Pending-review loading, address resolution, trading-key preparation, fee pricing,
quote validation and renewal, signing, submission, deferred registration, nonce
rechecks, cleanup failures and recovery errors are logged. Cancellation is an
INFO outcome. No passcodes, mnemonics, private keys, authorization headers,
signatures or signed transaction bytes are added to these fields; operation HTTP
request bodies and successful response bodies are suppressed. Bounded HTTP error
envelopes remain available, including undocumented backend failures, and so does a
2xx deposit quote the client could not decode (`stage=quote`, `outcome=undecodable`):
signatures travel only in the quote request, never in its response. Public transaction hashes and backend IDs remain
available for server-side investigation.

Trading uses `flow=trade` with `action=open|close|size_change|margin_change|auto_close_change|limit_order_change|auto_close_rebase`,
`market_id`, side, size/margin/leverage, slippage and order prices when applicable.
Preview/prepare traces link to `operation_id` when the plan is ready. From submit
onward, `trace_id=operation_id`, including recovery and SDK execution callbacks.
`step_id`, `attempt_id`, nonce, transaction type/hash, order indices and durable
step states identify each prerequisite and order without its signed payload.

Follow `prepare_*` → `plan` → `submit` → `sign` → `l2_send` → `reconcile`.
A submit `accepted` means the venue acknowledged the signed transaction;
`confirmed` and `partially_filled` are reconciliation results. Transport errors
can leave submission `unknown`; failed reads leave reconciliation pending.
UI polling ends with `stage=ui_settle` and
`outcome=confirmed|partially_filled|failed|unknown|cancelled`;
`reason=poll_limit_reached` explains an unresolved UI result, without declaring
the order rejected. Local no-op and cancellation are INFO events. Journal
read/write failures and durable state changes are logged on their IO context.
