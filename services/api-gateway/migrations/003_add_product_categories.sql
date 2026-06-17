ALTER TABLE products
ADD COLUMN categories JSONB NOT NULL DEFAULT '[]'::jsonb
  CHECK (
    jsonb_typeof(categories) = 'array'
    AND jsonb_array_length(categories) <= 8
  );

CREATE INDEX products_categories_gin_idx ON products USING GIN (categories);
