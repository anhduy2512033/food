import 'store.dart';
import 'user.dart';

class Favorite {
  String id;
  User user;
  Store store;

  Favorite({
    required this.id,
    required this.user,
    required this.store,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': user.id,
      'storeId': store.id,
    };
  }

  factory Favorite.fromMap(
      Map<String, dynamic> map,
      Map<String, User> users,
      Map<String, Store> stores,
      ) {
    // Get user and store IDs
    String userId = map['userId']?.toString() ?? '';
    String storeId = map['storeId']?.toString() ?? '';

    // Get corresponding user and store objects
    User? user = users[userId];
    Store? store = stores[storeId];

    if (user == null || store == null) {
      throw Exception('User or Store not found for favorite ${map['id']}');
    }

    return Favorite(
      id: map['id']?.toString() ?? '',
      user: user,
      store: store,
    );
  }
}