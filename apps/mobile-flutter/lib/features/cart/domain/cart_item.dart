class CartItem {
  const CartItem({
    required this.productId,
    required this.selectedColors,
    required this.quantity,
    required this.isSelected,
  });

  final String productId;
  final Map<String, String> selectedColors;
  final int quantity;
  final bool isSelected;

  CartItem copyWith({int? quantity, bool? isSelected}) {
    return CartItem(
      productId: productId,
      selectedColors: selectedColors,
      quantity: quantity ?? this.quantity,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
