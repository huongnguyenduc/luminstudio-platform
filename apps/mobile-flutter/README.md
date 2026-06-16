# Mobile Flutter

Flutter customer application for catalog navigation, search, 360 previews, 3D
product interaction, configuration, and local cart management.

Phase 3 now provides the first executable Flutter application boundary for
Android and iOS. The app shell exposes Home, Category, and Cart tabs with state
retained while users switch tabs. The Home tab loads customer-safe catalog
product cards from the Go API `GET /catalog/products` route through a
repository/use-case boundary. Search, category pagination, 360-degree previews,
product detail, cart persistence, and executable Bazel Flutter targets remain
deferred.

Verify the shell from the repository root:

```bash
bash scripts/verify-us-030.sh
```

Verify catalog products API integration from the repository root:

```bash
bash scripts/verify-us-031.sh
```
