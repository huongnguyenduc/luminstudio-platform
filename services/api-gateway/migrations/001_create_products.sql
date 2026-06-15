CREATE TYPE product_processing_status AS ENUM (
  'not_started',
  'queued',
  'processing',
  'completed',
  'failed'
);

CREATE TABLE products (
  id TEXT PRIMARY KEY
    CHECK (id ~ '^prod_[A-Za-z0-9][A-Za-z0-9_-]{7,63}$'),
  slug TEXT NOT NULL UNIQUE
    CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) <= 180),
  name TEXT NOT NULL
    CHECK (length(name) >= 1 AND length(name) <= 160),
  description TEXT NOT NULL
    CHECK (length(description) >= 1 AND length(description) <= 10000),
  information_sections JSONB NOT NULL DEFAULT '[]'::jsonb
    CHECK (jsonb_typeof(information_sections) = 'array'),
  mesh_color_config JSONB
    CHECK (mesh_color_config IS NULL OR jsonb_typeof(mesh_color_config) = 'object'),
  source_asset JSONB
    CHECK (source_asset IS NULL OR jsonb_typeof(source_asset) = 'object'),
  optimized_asset JSONB
    CHECK (optimized_asset IS NULL OR jsonb_typeof(optimized_asset) = 'object'),
  sprite_asset JSONB
    CHECK (sprite_asset IS NULL OR jsonb_typeof(sprite_asset) = 'object'),
  processing_status product_processing_status NOT NULL DEFAULT 'not_started',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (updated_at >= created_at)
);

CREATE INDEX products_processing_status_idx ON products (processing_status);
CREATE INDEX products_updated_at_idx ON products (updated_at);
