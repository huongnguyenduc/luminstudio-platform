class CartItem {
  const CartItem({
    required this.productId,
    required this.productName,
    required this.amountCents,
    required this.currency,
    required this.selectedColors,
    required this.quantity,
    required this.isSelected,
    this.compareAtAmountCents,
  });

  final String productId;
  final String productName;
  final int amountCents;
  final String currency;
  final int? compareAtAmountCents;
  final Map<String, String> selectedColors;
  final int quantity;
  final bool isSelected;

  CartItem copyWith({int? quantity, bool? isSelected}) {
    return CartItem(
      productId: productId,
      productName: productName,
      amountCents: amountCents,
      currency: currency,
      compareAtAmountCents: compareAtAmountCents,
      selectedColors: selectedColors,
      quantity: quantity ?? this.quantity,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  int get lineSubtotalCents => amountCents * quantity;

  int get lineSavingsCents {
    final compareAt = compareAtAmountCents;
    if (compareAt == null || compareAt <= amountCents) {
      return 0;
    }
    return (compareAt - amountCents) * quantity;
  }
}
