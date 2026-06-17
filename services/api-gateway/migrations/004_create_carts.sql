CREATE TABLE carts (
  id TEXT PRIMARY KEY
    CHECK (id ~ '^cart_[A-Za-z0-9][A-Za-z0-9_-]{7,63}$'),
  items JSONB NOT NULL DEFAULT '[]'::jsonb
    CHECK (jsonb_typeof(items) = 'array' AND jsonb_array_length(items) <= 100),
  totals JSONB NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(totals) = 'object'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (updated_at >= created_at)
);

CREATE INDEX carts_updated_at_idx ON carts (updated_at);
