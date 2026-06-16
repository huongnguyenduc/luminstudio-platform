ALTER TABLE products
ADD COLUMN price JSONB NOT NULL DEFAULT '{"amountCents":1,"currency":"USD"}'::jsonb
  CHECK (
    jsonb_typeof(price) = 'object'
    AND (price ? 'amountCents')
    AND (price ? 'currency')
    AND (price->>'amountCents') ~ '^[0-9]+$'
    AND (price->>'currency') ~ '^[A-Z]{3}$'
    AND (
      NOT (price ? 'compareAtAmountCents')
      OR (price->>'compareAtAmountCents') ~ '^[0-9]+$'
    )
  );
