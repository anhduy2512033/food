import 'ingredients_item.dart';
import'restaurant.dart';
import'category.dart';

class Food {
  int? id;
  String? name;
  String? description;
  int? price; // Thay Long bằng int
  Category? foodCategory; // Mối quan hệ với Category
  List<String>? images; // Danh sách các hình ảnh
  bool? available; // Thay boolean bằng bool
  Restaurant? restaurant; // Mối quan hệ với Restaurant
  bool? isVegetarian;
  bool? isSeasonal;
  List<IngredientsItem>? ingredients; // Danh sách các nguyên liệu
  DateTime? creationDate; // Thay Date bằng DateTime

  Food({
    this.id,
    this.name,
    this.description,
    this.price,
    this.foodCategory,
    this.images,
    this.available,
    this.restaurant,
    this.isVegetarian,
    this.isSeasonal,
    this.ingredients,
    this.creationDate,
  });

  // Tạo đối tượng Food từ Map
  factory Food.fromMap(Map<String, dynamic> map) {
    return Food(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      price: map['price'],
      foodCategory: map['foodCategory'] != null
          ? Category.fromMap(map['foodCategory'])
          : null,
      images: map['images'] != null
          ? List<String>.from(map['images'])
          : [],
      available: map['available'],
      restaurant: map['restaurant'] != null
          ? Restaurant.fromMap(map['restaurant'])
          : null,
      isVegetarian: map['isVegetarian'],
      isSeasonal: map['isSeasonal'],
      ingredients: map['ingredients'] != null
          ? List<IngredientsItem>.from(map['ingredients'].map((item) => IngredientsItem.fromMap(item)))
          : [],
      creationDate: map['creationDate'] != null
          ? DateTime.parse(map['creationDate'])
          : null,
    );
  }

  // Chuyển đối tượng Food thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'foodCategory': foodCategory?.toMap(),
      'images': images,
      'available': available,
      'restaurant': restaurant?.toMap(),
      'isVegetarian': isVegetarian,
      'isSeasonal': isSeasonal,
      'ingredients': ingredients?.map((item) => item.toMap()).toList(),
      'creationDate': creationDate?.toIso8601String(),
    };
  }
}