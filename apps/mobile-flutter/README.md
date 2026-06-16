# Mobile Flutter

Flutter customer application for catalog navigation, search, 360 previews, 3D
product interaction, configuration, and local cart management.

Phase 3 now provides the first executable Flutter application boundary for
Android and iOS. The app shell exposes Home, Category, and Cart tabs with state
retained while users switch tabs. The Home tab loads customer-safe catalog
product cards from the Go API `GET /catalog/products` route through a
repository/use-case boundary. The Home tab also submits catalog searches to the
Go API `GET /catalog/search?q=...` route through the same boundary and renders
loading, empty, failure/retry, clear, and result states. The Home tab now
paginates both catalog and search result lists through the existing Go API
`limit` and `offset` parameters with inline load-more retry behavior. The Go
API now exposes completed sprite JPEGs at
`GET /catalog/products/{id}/sprite`; the Flutter Home tab activates those
sprite previews after a product card remains at least 80% visible and idle for
three seconds.
The Go API now also exposes product detail and tiered model routes through
`GET /catalog/products/{id}?tier=low|high` and
`GET /catalog/products/{id}/model?tier=low|high`. The Home tab now opens a
product detail screen from catalog cards, derives a low/high model tier, and
renders seller-provided sections, mesh color configuration, and gateway
model/sprite route metadata without direct storage access. The product detail
screen now renders the selected gateway model route with an interactive
rotate/zoom 3D viewer. Product detail mesh color configuration now renders as
selectable material swatches backed by local Flutter state. Product Detail can
now add the selected configuration to a locally persisted cart, and the Cart tab
renders stored product identity, selected colors, quantity, selection state,
selected subtotal, and savings from locally stored price snapshots. Category
taxonomy, sorting, checkout, payment, auth, inventory, discount engines, and
executable Bazel Flutter targets remain deferred.

Verify the shell from the repository root:

```bash
bash scripts/verify-us-030.sh
```

Verify catalog products API integration from the repository root:

```bash
bash scripts/verify-us-031.sh
```

Verify catalog search UI integration from the repository root:

```bash
bash scripts/verify-us-032.sh
```

Verify catalog pagination and infinite scroll from the repository root:

```bash
bash scripts/verify-us-033.sh
```

Verify 360-degree catalog preview activation from the repository root:

```bash
bash scripts/verify-us-035.sh
```

Verify product detail and device tier integration from the repository root:

```bash
bash scripts/verify-us-037.sh
```

Verify the interactive 3D product viewer from the repository root:

```bash
bash scripts/verify-us-038.sh
```

Verify material color selection from the repository root:

```bash
bash scripts/verify-us-039.sh
```

Verify local cart persistence from the repository root:

```bash
bash scripts/verify-us-040.sh
```

Verify product pricing contract and cart totals from the repository root:

```bash
bash scripts/verify-us-041.sh
```
