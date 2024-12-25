import 'package:flutter_application_2/src/model/restaurant.dart';

import 'ingredient_category.dart';

class IngredientsItem {
  int? id;
  String? name;
  IngredientCategory? category; // Mối quan hệ với IngredientCategory
  Restaurant? restaurant; // Mối quan hệ với Restaurant
  bool? inStock; // Trạng thái còn hàng (thay boolean bằng bool)

  IngredientsItem({
    this.id,
    this.name,
    this.category,
    this.restaurant,
    this.inStock = true,
  });

  // Tạo đối tượng IngredientsItem từ Map
  factory IngredientsItem.fromMap(Map<String, dynamic> map) {
    return IngredientsItem(
      id: map['id'],
      name: map['name'],
      category: map['category'] != null
          ? IngredientCategory.fromMap(map['category'])
          : null,
      restaurant: map['restaurant'] != null
          ? Restaurant.fromMap(map['restaurant'])
          : null,
      inStock: map['inStock'] ?? true, // Mặc định là true nếu không có giá trị
    );
  }

  // Chuyển đối tượng IngredientsItem thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category?.toMap(),
      'restaurant': restaurant?.toMap(),
      'inStock': inStock,
    };
  }
}