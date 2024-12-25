import 'category.dart';
import 'store.dart';

class Product {
  final String id;
  final String name;
  Store store;
  Category category;
  double price;
  String description;
  String status;
  double rating;
  String? image;
  String? thumbnail;

  Product({
    required this.id,
    required this.name,
    required this.store,
    required this.category,
    required this.price,
    required this.description,
    required this.status,
    required this.rating,
    this.image,
    this.thumbnail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': store.id,
      'categoryId': category.id,
      'name': name,
      'price': price,
      'description': description,
      'status': status,
      'rating': rating,
      'image': image,
      'thumbnail': thumbnail,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory Product.fromMap(
      Map<String, dynamic> map,
      Map<String, Store> stores,
      Map<String, Category> categories,
      ) {
    final storeId = map['store_id']?.toString() ?? '';
    final categoryId = map['category_id']?.toString() ?? '';

    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      image: map['image']?.toString() ?? '',
      thumbnail: map['thumbnail']?.toString() ?? '',
      store: stores[storeId] ?? Store(
        id: storeId,
        name: '',
        description: '',
        phoneNumber: '',
        address: '',
        status: '',
        rating: 0,
      ),
      category: categories[categoryId] ?? Category(
        id: categoryId,
        name: '',
        description: '',
      ),
    );
  }
}