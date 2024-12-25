import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import '../../model/cart.dart';
import '../../model/cartItem.dart';
import '../../model/store.dart';
import '../../model/user.dart' as app_user;
import '../../service/CartService.dart';
import 'package:firebase_database/firebase_database.dart';
import 'checkoutScreen.dart';

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  Cart? currentCart;
  List<CartItem> cartItems = [];
  String? storeId;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  void _loadCart() {
    final user = auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('Loading cart for user: ${user.uid}');
      _database
          .child('carts')
          .orderByChild('userId')
          .equalTo(user.uid)
          .onValue
          .listen((event) async {
        if (event.snapshot.value != null) {
          try {
            final data = event.snapshot.value as Map<dynamic, dynamic>;

            // Chỉ lấy giỏ hàng pending và chưa thanh toán
            final pendingCart = data.entries.firstWhere(
              (entry) {
                final cartData = entry.value as Map;
                return cartData['status'] == 'pending' &&
                    cartData['isPaid'] == 0;
              },
              orElse: () => MapEntry('', {}),
            );

            if (pendingCart.key.isEmpty) {
              setState(() {
                currentCart = null;
                cartItems = [];
              });
              return;
            }

            print('Found pending cart: ${pendingCart.key}'); // Debug log
            final cartData =
                Map<String, dynamic>.from(pendingCart.value as Map);

            // Lấy thông tin store
            final storeSnapshot = await _database
                .child('stores')
                .child(cartData['storeId'])
                .get();

            if (storeSnapshot.value != null) {
              final storeData =
                  Map<String, dynamic>.from(storeSnapshot.value as Map);
              final storeId = cartData['storeId'];

              final cart = Cart(
                id: pendingCart.key,
                user: app_user.User(
                  id: user.uid,
                  fullName: '',
                  email: '',
                  phone: '',
                ),
                store: Store(
                  id: storeId,
                  name: storeData['name'] ?? '',
                  description: storeData['description'] ?? '',
                  phoneNumber: storeData['phoneNumber'] ?? '',
                  address: storeData['address'] ?? '',
                  status: storeData['status'] ?? '',
                  rating: (storeData['rating'] as num?)?.toDouble() ?? 0,
                ),
                createdAt: cartData['createdAt'] ?? 0,
              );

              setState(() {
                currentCart = cart;
              });

              // Lắng nghe thay đổi của cartItems
              _cartService.getCartItems(cart.id).listen(
                (items) {
                  print('Received ${items.length} cart items'); // Debug log
                  if (mounted) {
                    setState(() {
                      cartItems = items;
                    });
                  }
                },
                onError: (error) {
                  print('Error loading cart items: $error');
                  if (mounted) {
                    setState(() {
                      cartItems = [];
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Không thể tải giỏ hàng: ${error.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              );
            }
          } catch (e) {
            print('Error in _loadCart: $e');
          }
        } else {
          print('No carts found for user'); // Debug log
          setState(() {
            currentCart = null;
            cartItems = [];
          });
        }
      });
    }
  }

  void _removeAllItems() async {
    if (currentCart != null) {
      try {
        await _cartService.clearCart(currentCart!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tất cả sản phẩm')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    }
  }

  void _updateQuantity(CartItem item, bool isIncrease) async {
    try {
      int newQuantity = isIncrease ? item.quantity + 1 : item.quantity - 1;
      if (newQuantity <= 0) {
        await _cartService.removeFromCart(item.id);
      } else {
        await _cartService.updateCartItemQuantity(item.id, newQuantity);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  double _calculateTotal() {
    return cartItems.fold(
        0, (total, item) => total + (item.price * item.quantity));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Giỏ hàng (${cartItems.length} sản phẩm)',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _removeAllItems,
              tooltip: 'Xóa tất cả',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 100, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Giỏ hàng trống',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return CartItemWidget(
                        item: item,
                        onIncrease: () => _updateQuantity(item, true),
                        onDecrease: () => _updateQuantity(item, false),
                      );
                    },
                  ),
          ),
          if (cartItems.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng tiền:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '${_calculateTotal().toStringAsFixed(0)}đ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutScreen(
                            cart: currentCart!,
                            cartItems: cartItems,
                            totalAmount: _calculateTotal(),
                          ),
                        ),
                      );
                    },
                    child: Text('Đặt hàng'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class CartItemWidget extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const CartItemWidget({
    Key? key,
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hình ảnh sản phẩm
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.product.image ?? 'placeholder_url',
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[300],
                    child: Icon(Icons.image_not_supported),
                  );
                },
              ),
            ),
            SizedBox(width: 12),

            // Thông tin sản phẩm
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${item.price.toStringAsFixed(0)}đ',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Nút tăng giảm số lượng
            Container(
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: Icon(Icons.remove, size: 16),
                      onPressed: onDecrease,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ),
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: Icon(Icons.add, size: 16),
                      onPressed: onIncrease,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
