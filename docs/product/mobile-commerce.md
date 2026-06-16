# Mobile Commerce

## Architecture

The customer application uses Flutter, feature-oriented Clean Architecture,
and BLoC/Cubit state management. Presentation depends on domain use cases; data
adapters implement API and local persistence contracts.

## Catalog And Navigation

- Bottom navigation exposes Home, Category, and Cart.
- Each tab retains its navigation and scroll state when users switch tabs.
- Category detail supports pagination, infinite scrolling, and sorting.
- A scroll-to-top control appears away from the top and disappears at the top.

`US-030` introduces the first executable Flutter shell for Android and iOS with
Home, Category, and Cart tabs. It keeps tab scroll and nested navigation state
without adding catalog API integration, search, category pagination, previews,
product detail, or cart persistence.

`US-031` connects the Home tab to the Go API `GET /catalog/products` route and
loads catalog product cards through the API boundary. The Flutter app parses the
v1 catalog response behind a repository/use-case boundary and renders loading,
empty, failure, and product-list states. The app still does not activate
360-degree previews, request product detail, expose search UI, persist cart
state, or connect directly to Meilisearch, PostgreSQL, MinIO, or NATS.

`US-032` adds Home tab catalog search through the Go API
`GET /catalog/search?q=...` route. The Flutter app keeps the search request
behind the same repository/use-case boundary as catalog browsing and renders
search loading, empty, failure/retry, clear, and result states. Category
taxonomy, sorting, pagination controls, 360-degree preview activation, product
detail, signed object URLs, cart persistence, and direct service access remain
deferred.

`US-033` loads additional catalog and search pages from the Home tab using the
existing limit and offset API parameters. The Flutter Cubit tracks page size,
offset, total count, loading-more state, and inline retry state behind the same
repository/use-case boundary. Category taxonomy, sorting controls, 360-degree
preview activation, product detail, signed object URLs, cart persistence, and
direct service access remain deferred.

`US-034` exposes processed 360-degree sprite assets through the Go API route
`GET /catalog/products/{id}/sprite`. The route streams a JPEG only when the
authoritative product record is completed and has a sprite asset in
`lumin-360-sprites`.

`US-035` activates processed sprite previews on Flutter Home tab product cards.
The catalog API adapter derives `GET /catalog/products/{id}/sprite` preview
URIs for products that include `spriteAsset`; product cards use
`VisibilityDetector` plus layout measurement to activate after the card is at
least 80% visible and scrolling is idle for three seconds. Resuming scroll or
leaving visibility cancels pending activation and stops the active preview.
Product detail, signed object URLs, cart persistence, and direct service access
remain deferred.

## 360-Degree Catalog Preview

When a product item remains more than 80% visible and scrolling has stopped for
three seconds, the app loads its sprite asset and starts a smooth 360-degree
preview. Visibility is measured with `VisibilityDetector`. Leaving visibility
or resuming scrolling cancels pending activation.

## Search

The app sends search queries to the Go API, which queries Meilisearch. Search
must tolerate common misspellings. The source target is less than 100 ms for
the search path; the benchmark environment and percentile are still to be
defined before this becomes release proof.

The backend now maintains the first derived Meilisearch `products` index from
admin product mutations through `product.updated` events. Customer-facing
catalog and search HTTP routes are selected as the first Phase 3 slice:
`GET /catalog/products` returns paginated product cards, and
`GET /catalog/search?q=...` returns typo-tolerant search results through the Go
API boundary. Both routes query Meilisearch from the API gateway and return the
same v1 catalog search response shape, including the 360-degree sprite asset
reference when the processed product document has one.
The Flutter Home tab now submits customer search queries to that API route and
renders the returned catalog cards without connecting directly to Meilisearch.
It also paginates both catalog browsing and search result lists through the
same Go API boundary. Processed sprite previews are retrieved and activated
through `GET /catalog/products/{id}/sprite`; mobile clients still do not access
MinIO directly.

## Product Detail And Device Tier

- The app derives a device tier from OS and memory/device information at
  startup using `device_info_plus` or an equivalent accepted implementation.
- Product detail requests include `tier=low` or `tier=high`.
- The API returns the matching GLB URL.
- The viewer supports rotate, zoom, and immediate material color changes for
  configured mesh identifiers through the selected viewer bridge/API.
- Product details include seller-provided sections and related products.

`US-036` adds the first backend product-detail boundary:
`GET /catalog/products/{id}?tier=low|high` returns one completed product's
seller-provided information sections, mesh color configuration, sprite route,
and model route through the Go API gateway. The companion
`GET /catalog/products/{id}/model?tier=low|high` route streams GLB bytes after
checking the authoritative product row. The low tier uses the optimized GLB
output, and the high tier uses the source GLB. Flutter device-tier detection,
the Flutter 3D viewer, material color editing, related products, signed object
URLs, cart persistence, and direct service access remain deferred.

`US-037` connects Flutter to that product-detail boundary. Tapping a Home
catalog product opens a detail screen, the app derives a low/high model tier
from local device characteristics, and the repository requests
`GET /catalog/products/{id}?tier=low|high` through the Go API base URL. The
screen renders loading, failure/retry, and ready states with seller-provided
sections, mesh color configuration, selected model tier, gateway model route,
and optional sprite route metadata. The interactive Flutter 3D viewer,
material color editing, related products, signed object URLs, cart persistence,
and direct service access remain deferred.

`US-038` adds the first interactive Flutter 3D viewer to the product detail
ready state. The viewer receives the gateway `modelUrl` selected by the
resolved low/high device tier and enables rotate plus zoom controls through the
selected Flutter viewer bridge. Material color editing, related products,
signed object URLs, cart persistence, live backend proof, live device proof,
and direct service access remain deferred.

`US-039` turns Product Detail mesh color configuration into customer-selectable
material swatches. Each mesh initializes to its configured default color, only
allowed colors can be selected, and the selected color map remains in
`ProductDetailCubit` state for later cart use. Related products, signed object
URLs, cart persistence, live backend proof, live device proof, and direct
service access remain deferred.

`US-040` lets customers add the selected Product Detail configuration to a
locally persisted cart. The cart stores product identity, selected mesh colors,
quantity, and selection state through a local Flutter repository and renders
that state on the Cart tab. Backend cart APIs, checkout, payments, inventory
checks, pricing precision, currency, discount rules, authentication,
authorization, signed object URLs, live backend proof, live device proof, and
direct service access remain deferred.

`US-041` defines the first display pricing contract for products. Product
drafts, records, catalog items, and product details include integer-cent
amounts, uppercase three-letter currency codes, and optional compare-at amounts.
The Flutter app parses this API-owned price, displays it on Product Detail,
snapshots it into local cart items, and recalculates selected subtotal and
savings when quantity or selection changes. Checkout, payments, authentication,
authorization, backend cart APIs, inventory checks, discount engines, tax,
shipping, settlement, live backend proof, live device proof, and direct service
access remain deferred.

`US-042` defines the first customer-facing category taxonomy API. Product
drafts and records may include up to eight category slug/name pairs. Search sync
indexes those categories into Meilisearch, and the Go API exposes
`GET /catalog/categories` plus
`GET /catalog/categories/{slug}/products?sort=newest|price_asc|price_desc|name_asc`
through the gateway. Category product results reuse the catalog pagination
envelope and still keep mobile clients behind the API boundary. Flutter
Category tab UI, checkout, payments, authentication, authorization, inventory
checks, backend cart APIs, live backend proof, live device proof, and direct
service access remain deferred.

`US-043` connects the Flutter Category tab to those API routes. The app lists
categories, loads the selected category's products, supports the v1 sort values,
paginates category product results, renders incremental retry and end-of-list
states, exposes scroll-to-top away from the top of the list, and opens existing
Product Detail from category product rows. Checkout, payments, authentication,
authorization, inventory checks, backend cart APIs, signed object URLs, Flutter
Bazel rules, live backend proof, live device proof, and direct service access
remain deferred.

`US-044` adds a Bazel-owned validation boundary for the Flutter customer app.
The Bazel target copies the app into a test temporary directory, then runs
`flutter pub get`, `dart format --set-exit-if-changed lib test`,
`flutter analyze`, the existing US-040 golden refresh, and `flutter test`
without mutating the source checkout.
Checkout, payments, authentication, authorization, inventory checks, backend
cart APIs, signed object URLs, production mobile release packaging, live backend
proof, live device proof, and direct service access remain deferred.

`US-049` adds live backend proof for the existing customer catalog and product
detail API boundaries. A processed product created from the admin upload and
worker pipeline is verified through catalog browsing, search, category
products, product detail, sprite streaming, and low/high model streaming routes
behind the Go API gateway. It does not add Flutter live device proof, checkout,
payments, authentication, authorization, backend cart APIs, signed object URLs,
or direct service access.

`US-050` adds live simulator proof for the existing Flutter customer commerce
flow. The verifier selects a completed processed product from a running Go API
gateway, launches the Flutter app on an iOS simulator with `LUMIN_API_BASE_URL`
pointing at that gateway, and drives Home catalog browsing, search, Category
tab browsing, Product Detail, high-tier model route metadata, material color
selection, Add to cart, and Cart subtotal rendering. It does not add checkout,
payments, authentication, authorization, inventory checks, backend cart APIs,
signed object URLs, new public contracts, or direct service access.

`US-051` adds the first backend cart API foundation. The Go API defines v1 cart
contracts, persists anonymous cart snapshots in PostgreSQL, and exposes
`POST /cart`, `GET /cart/{id}`, and `PUT /cart/{id}`. Cart create/update
requests send product ids, selected mesh colors, quantity, and selection state;
the API reads authoritative product rows, validates selected colors against the
configured mesh color options, snapshots product name, category, price,
processing status, and updated time, and recomputes totals server-side. Flutter
integration, checkout, payments, authentication, authorization, inventory
checks, tax, shipping, order fulfillment, signed object URLs, live backend
proof, live device proof, and direct service access remain deferred.

`US-052` connects the Flutter Cart feature to that backend cart API. The
default cart repository uses the app API base URL to create anonymous server
carts, read an existing saved cart id, and submit full cart replacements while
keeping the latest server item snapshot cached locally. Product Detail and Cart
tab mutations still send only product id, selected mesh colors, quantity, and
selection state; the API-owned response supplies product name, price, category,
processing status, and totals. Checkout, payments, authentication,
authorization, inventory checks, tax, shipping, order fulfillment, signed object
URLs, live backend proof, live device proof, and direct service access remain
deferred.

`US-053` adds live proof for that backend cart sync path. A running Go API
gateway and iOS simulator now verify cart create, read, update, saved cart id,
and fresh Cart tab hydration for a completed processed product. Checkout,
payments, authentication, authorization, inventory checks, tax, shipping, order
fulfillment, signed object URLs, new cart contracts, and direct service access
remain deferred.

`US-054` refines the existing Flutter commerce UI after live cart sync proof.
Catalog cards now expose category, price, preview readiness, and a clearer
detail affordance. Product Detail keeps model tier and preview readiness visible
without exposing internal model or sprite routes, moves customization closer to
the purchase decision, and keeps Add to cart available as a persistent bottom
action. Cart now presents a clearer summary, customer-friendly color swatches,
friendly mesh labels, and compact quantity controls. Checkout, payments,
authentication, authorization, inventory checks, tax, shipping, order
fulfillment, signed object URLs, new backend contracts, and direct service
access remain deferred.

`US-055` adds a deterministic Flutter UI/UX audit capture harness for the
current customer commerce surfaces. The harness captures Home, Category,
Product Detail top, Product Detail scrolled customization, and Cart at a
mobile-size viewport through fake repositories and injected model-viewer
behavior, so review artifacts do not depend on a live API gateway or manual
simulator navigation. It does not change the UI implementation, checkout,
payments, authentication, authorization, inventory checks, tax, shipping, order
fulfillment, signed object URLs, backend contracts, or direct service access.

`US-056` improves the Flutter Product Detail customize-to-cart path. The detail
screen now uses a mobile-responsive 3D viewer height, shows the selected finish
near the price, repeats the selected choice in the persistent Add to cart bar,
and lets customers add the configured item immediately after changing a swatch
without an extra scroll. Checkout, payments, authentication, authorization,
inventory checks, tax, shipping, order fulfillment, signed object URLs, new
backend contracts, and direct service access remain deferred.

`US-057` improves the Flutter Home and Category browse ergonomics. Home now
adds a small browse/result count and clearer catalog card hierarchy for
category, price, preview readiness, and detail entry. Category now uses
horizontal touch chips for sort choices, keeps the selected category and sort
visible above results, and renders category products with the same card
language as Home. Checkout, payments, authentication, authorization, inventory
checks, tax, shipping, order fulfillment, signed object URLs, new backend
contracts, and direct service access remain deferred.

## Cart

Cart state is persisted locally with product identity, product name, display
price snapshot, selected mesh colors, quantity, and selection state. The cart
recalculates selected subtotal and savings immediately when quantity or
selection changes. Totals are shown only when selected items share one currency.
The backend cart foundation stores the same customer-visible item shape behind
the Go API after validating products and selected colors against PostgreSQL.
Flutter now syncs its default cart repository with that API and retains the
local snapshot as a fallback cache. Live simulator proof now covers backend cart
create, update, saved id, and backend hydration for the Flutter Cart tab. The
Cart tab now renders friendlier summary, swatch, mesh-label, and quantity
controls while preserving the existing cart API and local fallback behavior.

Initial storage shape:

```json
{
  "product_id": "product-id",
  "product_name": "Product name",
  "amount_cents": 12900,
  "currency": "USD",
  "compare_at_amount_cents": 15900,
  "selected_colors": {"mesh_body": "#FF0000"},
  "qty": 1
}
```

Discount engines, inventory checks, tax, shipping, checkout, payments, auth,
and orders are not defined by the current product contract.
