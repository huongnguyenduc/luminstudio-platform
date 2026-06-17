/// Maps a hex color (admin-configured mesh finish) to a human-friendly finish
/// name shared by the product detail swatches and the cart line items, so the
/// customer never sees a raw `#RRGGBB` code.
///
/// Prefer an admin-provided label when one exists (see
/// `CatalogMeshColorOptions.labelForColor`); fall back to this curated palette
/// and finally to a generic label for unknown colors.
String finishNameForHex(String value) {
  switch (value.toUpperCase()) {
    case '#FFFFFF':
      return 'Porcelain white';
    case '#F8FAFC':
      return 'Soft white';
    case '#E5E7EB':
      return 'Mist grey';
    case '#CBD5E1':
      return 'Cloud grey';
    case '#94A3B8':
      return 'Slate grey';
    case '#64748B':
      return 'Storm grey';
    case '#475569':
      return 'Smoke grey';
    case '#334155':
      return 'Charcoal slate';
    case '#1F2937':
      return 'Graphite';
    case '#0F172A':
      return 'Midnight navy';
    case '#111827':
      return 'Ink black';
    case '#000000':
      return 'Black';
    case '#F5E6D3':
      return 'Warm linen';
    case '#D6B98C':
      return 'Natural oak';
    case '#C8A46A':
      return 'Aged brass';
    case '#B45309':
      return 'Cognac';
    case '#92400E':
      return 'Saddle brown';
    case '#78350F':
      return 'Walnut';
    case '#F59E0B':
      return 'Amber';
    case '#D97706':
      return 'Burnished brass';
    case '#16A34A':
      return 'Garden green';
    case '#0F766E':
      return 'Deep teal';
    case '#2563EB':
      return 'Cobalt blue';
    case '#7C3AED':
      return 'Violet';
    case '#DC2626':
      return 'Signal red';
    default:
      return 'Custom finish';
  }
}
