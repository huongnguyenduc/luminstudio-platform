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
`GET /catalog/products/{id}/sprite` for a later Flutter preview activation
story. Category taxonomy, sorting, 360-degree preview activation, product
detail, cart persistence, and executable Bazel Flutter targets remain
deferred.

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
