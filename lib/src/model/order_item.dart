import"food.dart";

class OrderItem {
  int? id;
  Food? food; // Mối quan hệ với Food
  int? quantity; // Số lượng sản phẩm
  int? totalPrice; // Tổng giá trị của sản phẩm
  List<String>? ingredients; // Danh sách các nguyên liệu

  OrderItem({
    this.id,
    this.food,
    this.quantity,
    this.totalPrice,
    this.ingredients,
  });

  // Tạo đối tượng OrderItem từ Map
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      food: map['food'] != null ? Food.fromMap(map['food']) : null,
      quantity: map['quantity'],
      totalPrice: map['totalPrice'],
      ingredients: map['ingredients'] != null
          ? List<String>.from(map['ingredients'])
          : [],
    );
  }

  // Chuyển đối tượng OrderItem thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'food': food?.toMap(),
      'quantity': quantity,
      'totalPrice': totalPrice,
      'ingredients': ingredients,
    };
  }
}