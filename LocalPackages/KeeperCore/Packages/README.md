# API targets

These directories contain separate Swift targets declared by `../Package.swift`.
The generated targets have no dependency on the `KeeperCore` domain target.
Application adapters, authorization and DTO mapping live in
`../Sources/KeeperCore/API/`.

`make -C ios <api>_generate` regenerates a client into `Sources/<target>`;
`make -C ios api_check` compares all clients with their specs.
Shared definitions live in `shared/api/` (`api/` in the public mirror),
and platform-only definitions live in `ios/scripts/apigen/schemas/`.
The public mirror keeps `scripts/apigen/schemas/` at its root.
All clients use the pinned `swift-openapi-generator`. Change generator
configuration rather than generated sources.

`TonStreamingAPIV2`, `EventSource` and `StreamURLSessionTransport` contain vendored
sources from [`tonkeeper/ton-api-swift` 0.8.0](https://github.com/tonkeeper/ton-api-swift/tree/716f7491aaa909bd4bcea23b1bd02f18e7de3e3c):
`Packages/ton-streaming-api-v2/Sources`, `Packages/EventSource/Sources` and
`Packages/StreamURLSessionTransport/Sources/StreamURLSessionTransport` respectively.
The transport target serves both buffered REST and incremental SSE responses.
The streaming target depends on both transport and EventSource. REST regeneration
leaves all three targets untouched.
