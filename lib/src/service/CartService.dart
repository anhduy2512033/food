import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import '../model/address.dart';
import '../model/cart.dart';
import '../model/cart_item.dart';
import '../model/category.dart';
import '../model/contact_information.dart';
import '../model/food.dart';
import '../model/ingredients_item.dart';
import '../model/restaurant.dart';
import '../model/user.dart';

class CartService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _cartsPath = 'carts';
  final String _cartItemsPath = 'cartItems';

  // Lấy giỏ hàng hiện tại của user
  Stream<Cart?> getCurrentCart(String userId, String storeId) {
    return _database
        .child(_cartsPath)
        .orderByChild('userId')
        .equalTo(userId)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;

      // Tìm cart chưa thanh toán cho store cụ thể
      final cartEntry = data.entries.firstWhere(
        (entry) => 
          (entry.value as Map)['storeId'] == storeId &&
          (entry.value as Map)['status'] == 'pending' &&
          (entry.value as Map)['isPaid'] == 0,
        orElse: () => MapEntry('', {}),
      );

      if (cartEntry.key.isEmpty) return null;

      return Cart.fromMap(
        {
          'id': cartEntry.key,
          ...Map<String, dynamic>.from(cartEntry.value as Map),
        },
      );
    });
  }

  // Lấy cart đang pending và chưa thanh toán của user
  Future<String> _getPendingCartId(String userId, String storeId) async {
    final cartsSnapshot = await _database
        .child(_cartsPath)
        .orderByChild('userId')
        .equalTo(userId)
        .get();

    if (cartsSnapshot.value != null) {
      final data = cartsSnapshot.value as Map<dynamic, dynamic>;
      // Tìm cart pending và chưa thanh toán của store
      final pendingCart = data.entries.firstWhere(
        (entry) => 
          (entry.value as Map)['storeId'] == storeId && 
          (entry.value as Map)['status'] == 'pending' &&
          (entry.value as Map)['isPaid'] == 0, // Thêm điều kiện isPaid
        orElse: () => MapEntry('', {}),
      );

      if (pendingCart.key.isNotEmpty) {
        return pendingCart.key;
      }
    }

    // Tạo cart mới nếu chưa có cart pending và chưa thanh toán
    final cartRef = _database.child(_cartsPath).push();
    await cartRef.set({
      'userId': userId,
      'storeId': storeId,
      'status': 'pending',
      'isPaid': 0, // Thêm trường isPaid mặc định là 0
      'createdAt': ServerValue.timestamp,
    });
    return cartRef.key!;
  }

  // Thêm phương thức kiểm tra giỏ hàng pending
  Future<bool> hasUnpaidCartFromOtherStore(String userId, String storeId) async {
    final cartsSnapshot = await _database
        .child(_cartsPath)
        .orderByChild('userId')
        .equalTo(userId)
        .get();

    if (cartsSnapshot.value != null) {
      final data = cartsSnapshot.value as Map<dynamic, dynamic>;
      // Tìm cart pending và chưa thanh toán của store khác
      final otherStoreCart = data.entries.firstWhere(
        (entry) => 
          (entry.value as Map)['storeId'] != storeId && 
          (entry.value as Map)['status'] == 'pending' &&
          (entry.value as Map)['isPaid'] == 0,
        orElse: () => MapEntry('', {}),
      );

      return otherStoreCart.key.isNotEmpty;
    }
    return false;
  }

  // Thêm sản phẩm vào giỏ hàng
  Future<void> addToCart(Food food, int quantity) async {
    try {
      final user = auth.FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Người dùng chưa đăng nhập');

      print('Adding to cart:');
      print('Product ID: ${food.id}');
      print('Store ID: ${food.restaurant?.id}');
      print('User ID: ${user.uid}');

      // Kiểm tra giỏ hàng chưa thanh toán hiện tại
      final currentCartSnapshot = await _database
          .child(_cartsPath)
          .orderByChild('userId')
          .equalTo(user.uid)
          .get();

      if (currentCartSnapshot.value != null) {
        final carts = currentCartSnapshot.value as Map<dynamic, dynamic>;
        final pendingCart = carts.entries.firstWhere(
          (entry) => 
            (entry.value as Map)['status'] == 'pending' &&
            (entry.value as Map)['isPaid'] == 0,
          orElse: () => MapEntry('', {}),
        );

        if (pendingCart.key.isNotEmpty) {
          final currentStoreId = (pendingCart.value as Map)['storeId'];
          
          // Nếu sản phẩm mới không cùng store
          if (currentStoreId != food.restaurant?.id) {
            throw Exception('Vui lòng thanh toán giỏ hàng hiện tại trước khi mua sắm từ cửa hàng khác');
          }

          // Nếu cùng store, thêm vào giỏ hàng hiện tại
          final cartId = pendingCart.key;
          await _addOrUpdateCartItem(cartId, user.uid, food, quantity);
          return;
        }
      }

      // Tạo giỏ hàng mới nếu chưa có giỏ hàng pending
      final cartRef = _database.child(_cartsPath).push();
      final cartId = cartRef.key!;
      
      final cartData = {
        'userId': user.uid,
        'storeId': food.restaurant?.id,
        'status': 'pending',
        'isPaid': 0,
        'createdAt': ServerValue.timestamp,
      };

      await cartRef.set(cartData);
      await _addOrUpdateCartItem(cartId, user.uid, food, quantity);
    } catch (e) {
      print('Error in addToCart: $e');
      rethrow;
    }
  }

  // Helper method để thêm hoặc cập nhật cartItem
  Future<void> _addOrUpdateCartItem(String cartId, String userId, Food food, int quantity) async {
    final existingItemSnapshot = await _database
        .child(_cartItemsPath)
        .orderByChild('cartId')
        .equalTo(cartId)
        .get();

    if (existingItemSnapshot.value != null) {
      final items = existingItemSnapshot.value as Map<dynamic, dynamic>;
      
      // Kiểm tra sản phẩm đã có trong giỏ hàng chưa
      for (var entry in items.entries) {
        final itemData = entry.value as Map;
        if (itemData['productId'] == food.id) {
          // Cập nhật số lượng nếu sản phẩm đã tồn tại
          final currentQuantity = itemData['quantity'] as int;
          await _database
              .child(_cartItemsPath)
              .child(entry.key)
              .update({'quantity': currentQuantity + quantity});
          return;
        }
      }
    }

    // Thêm sản phẩm mới vào giỏ hàng
    final cartItemRef = _database.child(_cartItemsPath).push();
    final cartItemData = {
      'id': cartItemRef.key,
      'cart': {'id': cartId}, // Chỉ lưu tham chiếu Cart với id
      'food': {
        'id': food.id,
        'name': food.name,
        'price': food.price,
        'images': [food.images],
        'description': food.description,
        'restaurant': {
          'id': food.restaurant?.id,
          'owner': food.restaurant?.owner != null ? food.restaurant?.owner?.toMap() : null,
          'name': food.restaurant?.name,
          'description': food.restaurant?.description,
          'cuisineType': food.restaurant?.cuisineType,
          'address': food.restaurant?.address != null ? food.restaurant?.address?.toMap() : null,
          'contactInformation': food.restaurant?.contactInformation != null
              ? food.restaurant?.contactInformation?.toMap()
              : null,
          'openingHours': food.restaurant?.openingHours,
          'images': food.restaurant?.images,
          'registrationDate': food.restaurant?.registrationDate?.toIso8601String(),
          'open': food.restaurant?.open,
        },

      }, // Thông tin món ăn
      'quantity': quantity,
      'ingredients': food.ingredients, // Nếu Food chứa danh sách nguyên liệu
      'totalPrice': food.price! * quantity, // Tổng giá trị
    };


    await cartItemRef.set(cartItemData);
  }

  // Cập nhật số lượng sản phẩm trong giỏ hàng
  Future<void> updateCartItemQuantity(String cartItemId, int newQuantity) async {
    try {
      await _database
          .child(_cartItemsPath)
          .child(cartItemId)
          .update({'quantity': newQuantity});
    } catch (e) {
      print('Error updating cart item quantity: $e');
      rethrow;
    }
  }

  // Xóa sản phẩm khỏi giỏ hàng
  Stream<List<CartItem>> getCartItems(String cartId) {
    print('Getting cart items for cartId: $cartId'); // Debug log

    return _database
        .child(_cartItemsPath)
        .orderByChild('cartId')
        .equalTo(cartId)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) {
        print('No cart items found'); // Debug log
        return [];
      }

      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        List<CartItem> items = [];

        print('Found ${data.length} cart items'); // Debug log

        for (var entry in data.entries) {
          try {
            final itemData = Map<String, dynamic>.from(entry.value as Map);
            print('Processing cart item: ${itemData.toString()}'); // Debug log để xem dữ liệu

            // Kiểm tra và đảm bảo các trường bắt buộc không null
            if (itemData['productId'] == null || itemData['cartId'] == null) {
              print('Skipping invalid cart item: ${entry.key}');
              continue;
            }

            items.add(CartItem(
              id: entry.key,
              cart: Cart(
                id: itemData['cartId'] as int?,
                customer: User(
                  id: (itemData['userId'] as int?)?.toString() ?? '',
                  fullName: itemData['userName'] ?? 'Khách hàng không xác định',
                  email: itemData['userEmail'] ?? '',
                  phone: itemData['userPhone'] ?? '',
                ),
                total: (itemData['totalPrice'] as num?)?.toInt() ?? 0,
                items: [], // Nếu muốn thêm danh sách items, cần xử lý thêm logic ở đây
              ),

              food: Food(
                id: itemData['productId'] as int?, // Đảm bảo id là kiểu int
                name: itemData['productName'] ?? 'Sản phẩm không xác định',
                description: itemData['productDescription'] ?? '',
                price: (itemData['price'] as num?)?.toInt() ?? 0,
                foodCategory: Category(
                  id: itemData['categoryId'] as int?,
                  name: itemData['categoryName'] ?? 'Danh mục không xác định',
                  restaurant: itemData['restaurantDescription'] ?? '',
                ),
                images: [
                  itemData['productImage'] ?? '',
                  itemData['productThumbnail'] ?? ''
                ],
                available: itemData['productAvailable'] as bool? ?? true,
                restaurant: Restaurant(
                  id: itemData['restaurantId'] as int?,
                  name: itemData['restaurantName'] ?? 'Nhà hàng không xác định',
                  description: itemData['restaurantDescription'] ?? '',
                  address: itemData['restaurantAddressId'] != null
                      ? Address(
                    id: itemData['restaurantAddressId'] as int?,
                  ) : null,
                  contactInformation: ContactInformation(
                    email: itemData['restaurantEmail'] ?? '',
                    mobile: itemData['restaurantPhone'] ?? '',
                    twitter: itemData['restaurantTwitter'] ?? '',
                    instagram: itemData['restaurantInstagram'] ?? '',
                  ),

                ),
                isVegetarian: itemData['isVegetarian'] as bool? ?? false,
                isSeasonal: itemData['isSeasonal'] as bool? ?? false,
                ingredients: itemData['ingredients'] != null
                    ? List<IngredientsItem>.from((itemData['ingredients'] as List).map(
                      (ingredient) => IngredientsItem.fromMap(ingredient),
                ))
                    : [],
                creationDate: itemData['creationDate'] != null
                    ? DateTime.parse(itemData['creationDate'])
                    : null,
              ),

              quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
              totalPrice: (itemData['price'] as num?)?.toInt() ?? 0,
            ));
          } catch (itemError) {
            print('Error processing cart item: $itemError');
            continue;
          }
        }

        print('Successfully loaded ${items.length} cart items'); // Debug log
        return items;
      } catch (e) {
        print('Error loading cart items: $e'); // Debug log
        rethrow; // Ném lỗi để có thể xử lý ở UI
      }
    });
  }


  // Xóa toàn bộ giỏ hàng
  Future<void> clearCart(String cartId) async {
    // Xóa tất cả cartItems của cart này
    final cartItemsSnapshot = await _database
        .child(_cartItemsPath)
        .orderByChild('cartId')
        .equalTo(cartId)
        .get();

    if (cartItemsSnapshot.value != null) {
      final items = cartItemsSnapshot.value as Map;
      for (var itemId in items.keys) {
        await _database.child(_cartItemsPath).child(itemId).remove();
      }
    }

    // Xóa cart
    await _database.child(_cartsPath).child(cartId).remove();
  }

  // Thanh toán giỏ hàng
  Future<void> checkout(String cartId, {
    required String recipientName,
    required String recipientAddress,
    required String recipientPhone,
    String? note,
  }) async {
    try {
      final cartRef = _database.child(_cartsPath).child(cartId);
      
      // Cập nhật trạng thái cart thành ordered và đã thanh toán
      await cartRef.update({
        'status': 'ordered',
        'isPaid': 1, // Cập nhật isPaid thành 1
        'recipientName': recipientName,
        'recipientAddress': recipientAddress,
        'recipientPhone': recipientPhone,
        'note': note,
        'orderedAt': ServerValue.timestamp,
      });

      // Cập nhật trạng thái của tất cả cartItems
      final cartItemsSnapshot = await _database
          .child(_cartItemsPath)
          .orderByChild('cartId')
          .equalTo(cartId)
          .get();

      if (cartItemsSnapshot.value != null) {
        final items = cartItemsSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in items.entries) {
          await _database
              .child(_cartItemsPath)
              .child(entry.key)
              .update({'status': 'ordered'});
        }
      }

      // Không cần tạo cart mới ở đây nữa vì sẽ tự tạo khi thêm sản phẩm mi
    } catch (e) {
      print('Error checking out cart: $e');
      rethrow;
    }
  }

  Future<void> checkAndRemoveEmptyCart(String cartId) async {
    final cartItemsSnapshot = await _database
        .child(_cartItemsPath)
        .orderByChild('cartId')
        .equalTo(cartId)
        .get();

    if (cartItemsSnapshot.value == null) {
      // Xóa giỏ hàng nếu không có item nào
      await _database.child(_cartsPath).child(cartId).remove();
      print('Removed empty cart: $cartId');
    }
  }
}