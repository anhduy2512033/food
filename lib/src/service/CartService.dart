import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import '../model/cart.dart';
import '../model/cartItem.dart';
import '../model/category.dart';
import '../model/product.dart';
import '../model/store.dart';
import '../model/user.dart' as app_user;

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
        cartEntry.key,
        Map<String, dynamic>.from(cartEntry.value as Map),
        users: {}, 
        stores: {},
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
  Future<void> addToCart(Product product, int quantity) async {
    try {
      final user = auth.FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Người dùng chưa đăng nhập');

      print('Adding to cart:');
      print('Product ID: ${product.id}');
      print('Store ID: ${product.store.id}');
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
          if (currentStoreId != product.store.id) {
            throw Exception('Vui lòng thanh toán giỏ hàng hiện tại trước khi mua sắm từ cửa hàng khác');
          }

          // Nếu cùng store, thêm vào giỏ hàng hiện tại
          final cartId = pendingCart.key;
          await _addOrUpdateCartItem(cartId, user.uid, product, quantity);
          return;
        }
      }

      // Tạo giỏ hàng mới nếu chưa có giỏ hàng pending
      final cartRef = _database.child(_cartsPath).push();
      final cartId = cartRef.key!;
      
      final cartData = {
        'userId': user.uid,
        'storeId': product.store.id,
        'status': 'pending',
        'isPaid': 0,
        'createdAt': ServerValue.timestamp,
      };

      await cartRef.set(cartData);
      await _addOrUpdateCartItem(cartId, user.uid, product, quantity);
    } catch (e) {
      print('Error in addToCart: $e');
      rethrow;
    }
  }

  // Helper method để thêm hoặc cập nhật cartItem
  Future<void> _addOrUpdateCartItem(String cartId, String userId, Product product, int quantity) async {
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
        if (itemData['productId'] == product.id) {
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
      'cartId': cartId,
      'userId': userId,
      'productId': product.id,
      'storeId': product.store.id,
      'quantity': quantity,
      'price': product.price,
      'createdAt': ServerValue.timestamp,
      'status': 'pending',
      'productName': product.name,
      'productImage': product.image,
      'productThumbnail': product.thumbnail,
      'productDescription': product.description,
      'productStatus': product.status,
      'productPrice': product.price,
      'storeName': product.store.name,
      'storePhone': product.store.phoneNumber,
      'storeAddress': product.store.address,
      'categoryId': product.category.id,
      'categoryName': product.category.name,
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
  Future<void> removeFromCart(String cartItemId) async {
    try {
      // Lấy thông tin cartItem trước khi xóa
      final cartItemSnapshot = await _database
          .child(_cartItemsPath)
          .child(cartItemId)
          .get();
          
      if (cartItemSnapshot.value != null) {
        final cartItemData = cartItemSnapshot.value as Map;
        final cartId = cartItemData['cartId'] as String;
        
        // Xóa cartItem
        await _database
            .child(_cartItemsPath)
            .child(cartItemId)
            .remove();
            
        // Kiểm tra và xóa giỏ hàng nếu rỗng
        await checkAndRemoveEmptyCart(cartId);
      }
    } catch (e) {
      print('Error removing cart item: $e');
      rethrow;
    }
  }

  // Lấy danh sách sản phẩm trong giỏ hàng
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
            if (itemData['productId'] == null || 
                itemData['cartId'] == null || 
                itemData['userId'] == null) {
              print('Skipping invalid cart item: ${entry.key}');
              continue;
            }

            items.add(CartItem(
              id: entry.key,
              cart: Cart(
                id: itemData['cartId'] ?? '',
                user: app_user.User(
                  id: itemData['userId'] ?? '',
                  fullName: itemData['userName'] ?? '',
                  email: itemData['userEmail'] ?? '',
                  phone: itemData['userPhone'] ?? '',
                ),
                store: Store(
                  id: itemData['storeId'] ?? '',
                  name: itemData['storeName'] ?? '',
                  description: '',
                  phoneNumber: '',
                  address: '',
                  status: '',
                  rating: 0,
                ),
                createdAt: itemData['createdAt'] ?? 0,
              ),
              product: Product(
                id: itemData['productId'] ?? '',
                name: itemData['productName'] ?? 'Sản phẩm không xác đnh',
                price: (itemData['price'] as num?)?.toDouble() ?? 0,
                description: itemData['productDescription'] ?? '',
                status: itemData['productStatus'] ?? '',
                rating: 0,
                image: itemData['productImage'] ?? '',
                thumbnail: itemData['productThumbnail'] ?? '',
                store: Store(
                  id: itemData['storeId'] ?? '',
                  name: itemData['storeName'] ?? '',
                  description: '',
                  phoneNumber: '',
                  address: '',
                  status: '',
                  rating: 0,
                ),
                category: Category(
                  id: itemData['categoryId'] ?? '',
                  name: itemData['categoryName'] ?? '',
                  description: ''
                ),
              ),
              quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
              price: (itemData['price'] as num?)?.toDouble() ?? 0,
              createdAt: itemData['createdAt'] ?? 0,
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
        rethrow; // Ném lỗi để có th xử lý ở UI
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