import 'restaurant.dart';

class Category {
  int? id;
  String? name;
  Restaurant? restaurant;

  Category({this.id, this.name, this.restaurant});

  // Tạo đối tượng Category từ Map
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      restaurant: map['restaurant'] != null ? Restaurant.fromMap(map['restaurant']) : null,
    );
  }

  // Chuyển đối tượng Category thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'restaurant': restaurant?.toMap(),
    };
  }
}
