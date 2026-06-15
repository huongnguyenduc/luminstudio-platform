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
catalog and search HTTP routes remain deferred until Phase 3 stories select
the mobile search surface.

## Product Detail And Device Tier

- The app derives a device tier from OS and memory/device information at
  startup using `device_info_plus` or an equivalent accepted implementation.
- Product detail requests include `tier=low` or `tier=high`.
- The API returns the matching GLB URL.
- The viewer supports rotate, zoom, and immediate material color changes for
  configured mesh identifiers through the selected viewer bridge/API.
- Product details include seller-provided sections and related products.

## Cart

Cart state is persisted locally with product identity, selected mesh colors,
quantity, and selection state. The cart recalculates subtotal and savings
immediately when quantity or selection changes.

Initial storage shape:

```json
{
  "product_id": "product-id",
  "selected_colors": {"mesh_body": "#FF0000"},
  "qty": 1
}
```

Pricing precision, currency, discount rules, inventory checks, and checkout are
not defined by the current product contract.
