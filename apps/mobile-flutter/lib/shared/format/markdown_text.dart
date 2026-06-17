/// Flattens a Markdown string into a clean single-paragraph plain-text preview.
///
/// Product descriptions are Markdown (headings, bold, lists, inline images) so
/// the detail page can render them richly. List cards, however, show a short
/// text snippet — without this they would leak raw syntax like `# Title` or
/// `![alt](url)`. This strips the common constructs and collapses whitespace.
String markdownToPlainText(String markdown) {
  var text = markdown;
  // Inline images: drop entirely (the snippet is text-only).
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
  // Links: keep the label, drop the target.
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (match) => match.group(1) ?? '',
  );
  // ATX headings (leading #), then list bullets at line start.
  text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s{0,3}[-*+]\s+', multiLine: true), '');
  // Remaining emphasis / code / quote / strike markers.
  text = text.replaceAll(RegExp(r'[*_`>~]'), '');
  // Collapse all runs of whitespace (incl. newlines) into single spaces.
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

/// Returns the URL of the first inline Markdown image (`![alt](url)`) in
/// [markdown], or null when there is none.
///
/// Product descriptions embed a representative still as
/// `![description](/catalog/products/{id}/image)`. Extracting it lets list and
/// cart cards lead with that image instead of the 360 sprite, and lets us skip
/// the network fetch entirely for products that ship no description image.
String? firstMarkdownImageUrl(String markdown) {
  final match = RegExp(r'!\[[^\]]*\]\(\s*([^)\s]+)').firstMatch(markdown);
  final url = match?.group(1);
  if (url == null || url.isEmpty) {
    return null;
  }
  return url;
}
