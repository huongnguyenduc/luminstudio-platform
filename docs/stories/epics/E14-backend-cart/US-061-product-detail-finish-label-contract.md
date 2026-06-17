# US-061 Product Detail Finish Label Contract

## Status

implemented

## Lane

normal

## Product Contract

Product Detail mesh color configuration can carry customer-facing finish labels
from the backend. Labels are keyed by allowed hex color values, validated by
the Go product domain, returned through the existing Product Detail response,
and used by Flutter before falling back to local color-name inference. Cart
selected colors remain authoritative hex values.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/roadmap.md`

## Acceptance Criteria

- Shared v1 mesh color contracts support optional labels keyed by hex color.
- Go product validation rejects invalid label keys, labels for disallowed
  colors, and empty labels.
- Customer Product Detail responses preserve mesh color labels.
- Flutter Product Detail parses labels and renders them in selected finish text
  and swatch semantics before falling back to local hex-name mapping.
- Cart mutations and saved selected-color values remain unchanged hex payloads.

## Design Notes

- Commands: none.
- Queries: Product Detail remains `GET /catalog/products/{id}?tier=low|high`.
- API: `meshColorConfig.<meshId>.labels` is optional and maps hex color values
  to customer-facing finish labels.
- Tables: no schema migration; existing `mesh_color_config` JSONB stores the
  extended object.
- Domain rules: label keys must be valid hex colors and must match an allowed
  color for the mesh; label text is 1-80 characters.
- UI surfaces: Flutter Product Detail customization labels and swatch
  accessibility labels.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-061 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Go product validation tests and Flutter catalog API parser tests cover finish labels. |
| Integration | Go catalog detail test proves labels are returned; Flutter widget tests prove Product Detail renders API labels. |
| E2E | Not required for this contract slice. |
| Platform | UI audit capture refreshes deterministic Product Detail screenshots. |
| Release | Deferred. |

## Harness Delta

No harness behavior changed.

## Evidence

- `bash scripts/verify-us-061.sh`
