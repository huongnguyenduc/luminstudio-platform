# US-059 Catalog Subtle 360 Idle Preview

## Status

implemented

## Lane

normal

## Product Contract

Catalog and category product cards must show a recognizable product image area
when a processed sprite is available. The app must crop one frame from the
existing 24-frame sprite sheet instead of exposing the full sheet. After a
visible card has been idle long enough, the preview may animate only as a
subtle left/right rotation around the front-facing frame.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`

## Acceptance Criteria

- Home product cards with `spritePreviewUri` render a single cropped product
  frame before idle preview activation.
- Home idle preview animation uses a short left/right frame sequence and no
  longer loops through all 24 sprite frames.
- Category product cards use the same cropped-frame and subtle idle-preview
  behavior as Home.
- Scrolling or leaving visibility still cancels pending or active preview
  animation.
- The story does not add checkout, payment, authentication, inventory, signed
  URL, backend contract, or direct platform-service access scope.

## Design Notes

- Commands:
  - `flutter test`
- Queries:
  - Existing `GET /catalog/products/{id}/sprite` gateway route only.
- API:
  - No new API contract.
- Tables:
  - No schema changes.
- Domain rules:
  - Keep the existing 24-frame, 6-by-4 sprite-sheet contract from US-025/US-035.
  - Use only a short near-front frame sequence for idle motion.
- UI surfaces:
  - Flutter Home product cards.
  - Flutter Category product cards.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-059 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Widget tests assert cropped sprite frame before idle and subtle preview after idle. |
| Integration | `flutter analyze` and full Flutter test suite pass. |
| E2E | Not required. |
| Platform | Deterministic US-055 audit captures refresh after media behavior changes. |
| Release | `bash scripts/verify-us-059.sh` passes. |

## Harness Delta

Add `US-059` with verifier `bash scripts/verify-us-059.sh`.

## Evidence

- `bash scripts/verify-us-059.sh` passed.
- `flutter analyze` passed.
- Full Flutter test suite passed.
- US-055 Home and Category audit screenshots refreshed after cropped sprite
  frame and subtle idle preview behavior.
