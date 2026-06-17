#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in bazelisk go grep; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to verify US-016" >&2
    exit 1
  fi
done

bash -n scripts/verify-us-016.sh

story_text="$(cat docs/stories/epics/E04-admin-api/US-016-product-persistence-foundation.md)"
migration_text="$(cat services/api-gateway/migrations/001_create_products.sql)"
product_text="$(cat services/api-gateway/internal/product/*.go)"

grep -q 'US-016 Product Persistence Foundation' <<<"$story_text"
grep -q 'This story does not add HTTP routes, admin UI behavior, MinIO uploads, NATS' <<<"$story_text"

for required in \
  'CREATE TABLE products' \
  'product_processing_status' \
  'information_sections JSONB' \
  'mesh_color_config JSONB' \
  'source_asset JSONB' \
  'optimized_asset JSONB' \
  'sprite_asset JSONB' \
  'UNIQUE' \
  'prod_' \
  'not_started'; do
  grep -q "$required" <<<"$migration_text"
done

for required in \
  'type ProductDraft struct' \
  'type ProductRecord struct' \
  'type MeshColorConfig map' \
  'func (draft ProductDraft) Validate() error' \
  'func NewInsertProductArgs' \
  'ProcessingNotStarted'; do
  grep -q "$required" <<<"$product_text"
done

if grep -Eqi 'HandleFunc|GET /|POST /|PUT /|nats\.Connect|Publish|Subscribe|minio\..*PutObject|meshoptimizer|Meili' \
  services/api-gateway/internal/product/*.go services/api-gateway/migrations/001_create_products.sql; then
  echo "US-016 must not add HTTP routes, runtime NATS, MinIO upload, worker processing, or search sync" >&2
  exit 1
fi

(cd services/api-gateway && go test ./...)
bazelisk test //services/api-gateway/internal/product:product_test
bazelisk build //services/api-gateway/migrations:migrations

echo "US-016 verification passed"
