# US-030 Flutter Customer App Shell

## Status

implemented

## Lane

normal

## Product Contract

The customer Flutter application has an executable mobile app boundary with a
Material shell and bottom navigation for Home, Category, and Cart. Each tab
keeps its own navigation and scroll state while users switch tabs, establishing
the Phase 3 mobile foundation for later catalog, search, 360-degree preview,
product detail, and cart stories.

This story does not add catalog API integration, search requests, category
pagination, sorting, 360-degree sprite preview activation, product detail,
device-tier GLB selection, local cart persistence, authentication,
authorization, or live K3d proof.

## Relevant Product Docs

- `docs/product/mobile-commerce.md`
- `docs/product/platform-foundation.md`
- `docs/product/roadmap.md`
- `docs/UI_SKILLS.md`

## Acceptance Criteria

- `apps/mobile-flutter` is a real Flutter application with Android and iOS
  platform shells, a `pubspec.yaml`, executable `lib/main.dart`, and tests.
- The app uses a feature-oriented layout with presentation state owned by a
  Cubit/BLoC boundary instead of placing tab state directly in widgets.
- Bottom navigation exposes Home, Category, and Cart tabs.
- Switching tabs preserves each tab's scroll position and nested navigation
  state.
- The shell includes loading-ready, empty-placeholder, and semantic labels
  appropriate for the scaffolded app state without implying catalog data exists.
- Verification proves Flutter dependency resolution, static analysis, widget
  tests, and a repository verifier for the selected non-goals.

## Design Notes

- Commands: `bash scripts/verify-us-030.sh`.
- Queries: none; this story has no API integration.
- API: none added.
- Tables: none added.
- Domain rules: mobile clients remain behind the Go API boundary; later stories
  will add API adapters for catalog/search.
- UI surfaces: Flutter customer app shell only.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-030 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Flutter widget tests cover tab labels, tab switching, Cubit state, and scroll-state retention. |
| Integration | Flutter static analysis passes and the repository verifier confirms project structure, dependency, docs, and non-goals. |
| E2E | Not required; no backend or device-run user flow is introduced. |
| Platform | Not required; no live K3d, Android emulator, or iOS simulator proof is required in this story. |
| Release | Not required. |

## Harness Delta

None expected.

## Evidence

- `dart format lib test` passed in `apps/mobile-flutter`.
- `flutter analyze` passed in `apps/mobile-flutter`.
- `flutter test` passed in `apps/mobile-flutter`.
- `bash scripts/verify-us-030.sh` passed.
