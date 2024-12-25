import 'package:flutter_application_2/src/model/restaurant.dart';

import 'ingredients_item.dart';

class IngredientCategory {
  int? id;
  String? name;
  Restaurant? restaurant; // Mối quan hệ với Restaurant
  List<IngredientsItem>? ingredients; // Danh sách các nguyên liệu

  IngredientCategory({
    this.id,
    this.name,
    this.restaurant,
    this.ingredients,
  });

  // Tạo đối tượng IngredientCategory từ Map
  factory IngredientCategory.fromMap(Map<String, dynamic> map) {
    return IngredientCategory(
      id: map['id'],
      name: map['name'],
      restaurant: map['restaurant'] != null
          ? Restaurant.fromMap(map['restaurant'])
          : null,
      ingredients: map['ingredients'] != null
          ? List<IngredientsItem>.from(map['ingredients'].map((item) => IngredientsItem.fromMap(item)))
          : [],
    );
  }

  // Chuyển đối tượng IngredientCategory thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'restaurant': restaurant?.toMap(),
      'ingredients': ingredients?.map((item) => item.toMap()).toList(),
    };
  }
}