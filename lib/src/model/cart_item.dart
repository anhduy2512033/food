import 'cart.dart';
import 'food.dart';
class CartItem {
  int? id;
  Cart? cart; // Mối quan hệ với Cart
  Food? food; // Mối quan hệ với Food
  int? quantity;
  List<String>? ingredients;
  int? totalPrice;

  CartItem({
    this.id,
    this.cart,
    this.food,
    this.quantity,
    this.ingredients,
    this.totalPrice,
  });

  // Tạo đối tượng CartItem từ Map
  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      cart: map['cart'] != null ? Cart.fromMap(map['cart']) : null,
      food: map['food'] != null ? Food.fromMap(map['food']) : null,
      quantity: map['quantity'],
      ingredients: map['ingredients'] != null ? List<String>.from(map['ingredients']) : [],
      totalPrice: map['totalPrice'],
    );
  }

  // Chuyển đối tượng CartItem thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cart': cart?.toMap(),
      'food': food?.toMap(),
      'quantity': quantity,
      'ingredients': ingredients,
      'totalPrice': totalPrice,
    };
  }
}