/// Formats a price in minor units (cents) as `CUR 12.34`.
String formatMoney(int cents, String currency) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '$currency $whole.$fraction';
}

/// Returns the rounded percentage discount of [amountCents] vs
/// [compareAtCents], or null when there is no genuine markdown.
int? discountPercent(int amountCents, int? compareAtCents) {
  if (compareAtCents == null || compareAtCents <= amountCents) {
    return null;
  }
  final pct = ((compareAtCents - amountCents) / compareAtCents) * 100;
  final rounded = pct.round();
  return rounded <= 0 ? null : rounded;
}
