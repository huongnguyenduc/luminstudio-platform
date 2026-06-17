# US-052 Flutter Backend Cart API Integration

## Status

implemented

## Lane

normal

## Product Contract

The Flutter customer app now synchronizes cart state through the Go API backend
cart boundary. Product Detail and Cart tab mutations still use the existing
`CartCubit`, but the default repository creates, reads, and updates anonymous
server-side carts through `POST /cart`, `GET /cart/{id}`, and `PUT /cart/{id}`.
The app stores the server cart id and the latest item snapshot locally so Cart
can load cached items when the backend cart cannot be reached.

This story does not add checkout, payments, authentication, authorization,
inventory checks, tax, shipping, order fulfillment, seller settlement, signed
object URLs, live backend proof, live device proof, or direct PostgreSQL,
MinIO, NATS, or Meilisearch access.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Flutter has a cart API client for `POST /cart`, `GET /cart/{id}`, and
  `PUT /cart/{id}` using the app API base URL.
- The default Flutter cart repository uses the Go API cart routes and preserves
  local cache/cart-id state through `SharedPreferences`.
- Cart load refreshes from the server when a cart id exists and falls back to
  local cached items if the backend cart is missing or unavailable.
- Cart mutations send only product id, selected mesh colors, quantity, and
  selected state; product name and pricing snapshots come back from the API
  record.
- Cart tab renders a visible sync state while backend cart mutations are in
  flight.
- Widget and data tests cover API request/response parsing, cart-id/cache sync,
  local fallback, and sync UI state.
- No checkout, payment, auth, inventory, signed URL, order, or direct platform
  service access is added.

## Design Notes

- Commands: Product Detail Add to cart and Cart tab quantity/selection updates
  persist through the backend cart API.
- Queries: Cart startup reads the saved server cart id, then loads
  `GET /cart/{id}` when possible.
- API: Reuses `POST /cart`, `GET /cart/{id}`, and `PUT /cart/{id}` from
  `US-051`; no new backend route is introduced.
- Local persistence: `SharedPreferences` stores the latest cart item snapshot
  and the server-owned cart id as a cache.
- UI surfaces: Cart tab shows a compact "Syncing cart" state during mutation.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-052 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Dart data and widget tests cover cart API parsing, repository sync, fallback, and sync UI state. |
| Integration | `flutter analyze`, `flutter test`, Bazel Flutter validation, and static verifier pass. |
| E2E | Not required; no live backend, checkout, payment, auth, or live device proof in this slice. |
| Platform | Not required; no K3d deployment or simulator proof changes in this slice. |
| Release | Deferred. |

## Harness Delta

Adds `scripts/verify-us-052.sh` and a Harness story row for Flutter backend
cart API integration.
