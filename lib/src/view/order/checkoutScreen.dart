import 'package:flutter/material.dart';
import '../../model/address.dart';
import '../../model/cart.dart';
import '../../model/cart_item.dart';
import '../../model/food.dart';
import '../../model/order.dart';
import '../../model/order_item.dart';
import '../../model/restaurant.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class CheckoutScreen extends StatefulWidget {
  final Cart cart;
  final List<CartItem> cartItems;
  final double totalAmount;

  CheckoutScreen({
    required this.cart,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _database = FirebaseDatabase.instance.ref();

  late TextEditingController _nameController = TextEditingController();
  late TextEditingController _phoneController = TextEditingController();
  late TextEditingController _addressController = TextEditingController();
  String? _note;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() async {
    final user = auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await _database.child('users').child(user.uid).get();
      if (snapshot.exists) {
        final userData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _addressController.text = userData['address'] ?? '';
        });
      }
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final orderId = _database.child('orders').push().key;
      if (orderId == null) throw Exception('Không thể tạo mã đơn hàng');

      // Lấy thông tin từ Cart
      final cart = widget.cart;
      final user = cart.customer; // Lấy người dùng từ Cart

      if (user == null) throw Exception('Không tìm thấy thông tin người dùng');

      // Tạo đối tượng đơn hàng
      final order = Order(
        id: int.tryParse(orderId),
        customer: user,
        //restaurant: restaurant,
        totalAmount: widget.totalAmount.toInt(),
        orderStatus: 'đang giao',
        createdAt: DateTime.now(),
        deliveryAddress: Address(id: null),
        items: [],
        totalItem: widget.cartItems.length,
        totalPrice: widget.totalAmount.toInt(),
      );

      // Lưu đơn hàng vào Firebase
      await _database.child('orders').child(orderId).set(order.toMap());

      // Lưu danh sách OrderItems vào Firebase
      final orderItemsRef = _database.child('orderItems').child(orderId);

      for (var item in widget.cartItems) {
        // Tạo một OrderItem mới dựa trên dữ liệu từ cartItems
        final orderItem = OrderItem(
          id: item.id, // ID sản phẩm
          food: Food(
            id: item.food?.id, // ID món ăn
            name: item.food?.name, // Tên món ăn
            price: item.food?.price, // Giá món ăn
            description: item.food?.description, // Mô tả món ăn
          ),
          quantity: item.quantity, // Số lượng
          totalPrice: ((item.food?.price ?? 0) * (item.quantity ?? 0)).toInt(),
          ingredients: item.ingredients, // Danh sách nguyên liệu
        );

        // Lưu OrderItem vào Firebase
        await orderItemsRef.push().set(orderItem.toMap());
      }


      // Cập nhật trạng thái giỏ hàng sau khi đặt hàng thành công
      await _database.child('carts').child(widget.cart.id?.toString() ?? '').update({
        'status': 'completed',
        'isPaid': 0,
      });

      // Thông báo đặt hàng thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đặt hàng thành công!')),
      );

      // Quay lại màn hình đầu tiên
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      // Xử lý lỗi nếu có
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Xác nhận đơn hàng'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chi tiết đơn hàng
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết đơn hàng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Divider(),
                      ...widget.cartItems
                          .map((item) => Padding(
                        padding:
                        EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.food?.name ?? 'N/A'} x${item.quantity ?? 0}',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            Text(
                              '${(item.totalPrice ?? 0).toString()}đ',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ))
                          .toList(),
                      Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng tiền:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.totalAmount.toStringAsFixed(0)}đ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Thông tin người nhận
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông tin người nhận',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Tên người nhận',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Vui lòng nhập tên người nhận';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Số điện thoại',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Vui lòng nhập số điện thoại';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Vui lòng nhập địa chỉ';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Ghi chú (tùy chọn)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _note = value,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Phương thức thanh toán
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phương thức thanh toán',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.money),
                          SizedBox(width: 8),
                          Text(
                            'Thanh toán khi nhận hàng',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Nút đặt hàng
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _createOrder,
                  child: Text(
                    'Xác nhận đặt hàng',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
