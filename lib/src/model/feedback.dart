import 'category.dart';
import 'store.dart';
import 'user.dart';
import 'product.dart';

class Feedback {
  String id;
  double rating;
  User user;
  Product product;
  String content;
  String? image;
  int createdAt;
  int updatedAt;

  Feedback({
    required this.id,
    required this.rating,
    required this.user,
    required this.product,
    required this.content,
    this.image,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rating': rating,
      'userId': user.id,
      'productId': product.id,
      'content': content,
      'image': image,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Feedback.fromMap(
    Map<String, dynamic> map,
    Map<String, dynamic> userData,
    Map<String, dynamic> productData,
  ) {
    return Feedback(
      id: map['id']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      user: User(
        id: userData['id'] ?? '',
        fullName: userData['name'] ?? 'Người dùng ẩn danh',
        email: userData['email'] ?? '',
        phone: userData['phone'] ?? '',
        createdAt: userData['createdAt'] as int?,
      ),
      product: Product(
        id: productData['id'] ?? '',
        name: productData['name'] ?? '',
        store: Store(
          id: productData['store_id'] ?? '',
          name: productData['store_name'] ?? '',
          description: '',
          phoneNumber: '',
          address: '',
          status: '',
          rating: 0,
        ),
        category: Category(
          id: productData['category_id'] ?? '',
          name: '',
          description: '',
        ),
        price: (productData['price'] as num?)?.toDouble() ?? 0,
        description: productData['description'] ?? '',
        status: productData['status'] ?? '',
        rating: (productData['rating'] as num?)?.toDouble() ?? 0,
        image: productData['image'],
      ),
      content: map['content']?.toString() ?? '',
      image: map['image']?.toString(),
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }
}
