import 'cartItem.dart';
import 'store.dart';
import 'user.dart';

class Cart {
  final String id;
  final User user;
  final Store store;
  final int createdAt;
  final int isPaid;
  final List<CartItem> items;

  Cart({
    required this.id,
    required this.user,
    required this.store,
    required this.createdAt,
    this.isPaid = 0,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': user.id,
      'storeId': store.id,
      'createdAt': createdAt,
      'isPaid': isPaid,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory Cart.fromMap(String id, Map<String, dynamic> map,
      {required Map<String, User> users,
      required Map<String, Store> stores}) {
    return Cart(
      id: id,
      user: users[map['userId']]!,
      store: stores[map['storeId']]!,
      createdAt: map['createdAt'] as int,
      isPaid: map['isPaid'] as int? ?? 0,
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromMap(item, 
                  carts: {}, 
                  products: {}, 
                  feedbacks: {}, 
                  orders: {}, 
                  stores: stores,
                  users: users))
              .toList() ??
          const [],
    );
  }
}