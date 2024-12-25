import 'cart_item.dart';
import 'user.dart';
class Cart {
  int? id;
  User? customer;
  int? total;
  List<CartItem> items = [];

  Cart({this.id, this.customer, this.total, this.items = const []});

  // Tạo đối tượng Cart từ Map
  factory Cart.fromMap(Map<String, dynamic> map) {
    return Cart(
      id: map['id'],
      customer: map['customer'] != null ? User.fromMap(map['customer']) : null,
      total: map['total'],
      items: map['items'] != null
          ? List<CartItem>.from(map['items'].map((item) => CartItem.fromMap(item)))
          : [],
    );
  }

  // Chuyển đối tượng Cart thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer': customer?.toMap(),
      'total': total,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
}