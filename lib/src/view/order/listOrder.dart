
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/address.dart';
import '../../model/food.dart';
import '../../model/ingredients_item.dart';
import '../../model/order.dart';
import '../../model/restaurant.dart';
import '../../model/user.dart' as app_user;
import 'orderDetail.dart';
import '../../model/category.dart';
class OrdersTab extends StatefulWidget {
  @override
  _OrdersTabState createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  List<Order> orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _database
        .child('orders')
        .orderByChild('userId')
        .equalTo(userId)
        .onValue
        .listen((event) async {
      if (event.snapshot.value == null) {
        setState(() => orders = []);
        return;
      }

      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        print('Found orders: ${data.length}');

        // Lấy thông tin users và stores
        final usersSnapshot = await _database.child('users').get();
        final storesSnapshot = await _database.child('stores').get();

        final users = <String, app_user.User>{};
        final stores = <String, Food>{};

        if (usersSnapshot.value != null) {
          final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
          usersData.forEach((key, value) {
            users[key.toString()] = app_user.User(
              id: key.toString(),
              fullName: value['name'] ?? '',
              email: value['email'] ?? '',
              phone: value['phone'] ?? '',
            );
          });
        }

        if (storesSnapshot.value != null) {
          final storesData = storesSnapshot.value as Map<dynamic, dynamic>;
          storesData.forEach((key, value) {
            stores[key.toString()] = Food(
              id: int.tryParse(key.toString()), // ID chuyển thành int
              name: value['name'] ?? '', // Tên món ăn
              description: value['description'] ?? '', // Mô tả món ăn
              price: value['price'] ?? 0, // Giá mặc định là 0 nếu không có
              foodCategory: value['foodCategory'] != null
                  ? Category.fromMap({
                ...value['foodCategory'],
                'restaurant': value['foodCategory']['restaurant'] != null
                    ? Restaurant.fromMap(value['foodCategory']['restaurant'])
                    : null,
              })
                  : null, // Thể loại món ăn

              images: value['images'] != null
                  ? List<String>.from(value['images'])
                  : [], // Danh sách hình ảnh
              available: value['available'] ?? true, // Mặc định là true nếu không có
              restaurant: value['restaurant'] != null
                  ? Restaurant.fromMap(value['restaurant'])
                  : null, // Thông tin nhà hàng
              isVegetarian: value['isVegetarian'] ?? false, // Mặc định không phải món chay
              isSeasonal: value['isSeasonal'] ?? false, // Mặc định không theo mùa
              ingredients: value['ingredients'] != null
                  ? List<IngredientsItem>.from(value['ingredients']
                  .map((item) => IngredientsItem.fromMap(item)))
                  : [], // Danh sách nguyên liệu
              creationDate: value['creationDate'] != null
                  ? DateTime.parse(value['creationDate'])
                  : null, // Ngày tạo món ăn
            );

          });
        }

        final loadedOrders = <Order>[];

        for (var entry in data.entries) {
          try {
            final orderData = Map<String, dynamic>.from(entry.value as Map);
            final storeId = orderData['storeId']?.toString();
            final userId = orderData['userId']?.toString();

            print(
                'Processing order: ${entry.key}, storeId: $storeId, userId: $userId');

            if (storeId != null && userId != null) {
              final store = stores[storeId];
              final user = users[userId];

              if (store != null && user != null) {
                final order = Order(
                  id: int.tryParse(entry.key), // ID đơn hàng
                  customer: user, // Người dùng (thay user cho customer)
                  //restaurant: restaurant, // Cửa hàng (Restaurant thay cho store)
                  orderStatus: orderData['status']?.toString() ?? '', // Trạng thái đơn hàng
                  totalAmount: (orderData['totalAmount'] as num?)?.toInt() ?? 0, // Tổng tiền
                  createdAt: DateTime.fromMillisecondsSinceEpoch(
                      orderData['createdAt'] as int? ?? 0), // Ngày tạo đơn hàng
                  deliveryAddress: orderData['deliveryAddress'] != null
                      ? Address.fromMap(orderData['deliveryAddress'] as Map<String, dynamic>)
                      : Address(
                    id: null, // Mặc định nếu không có thông tin
                  ),
                  items: [], // Danh sách sản phẩm (sẽ thêm sau)
                  totalItem: 0, // Tổng số sản phẩm (cần xử lý riêng)
                  totalPrice: (orderData['totalAmount'] as num?)?.toInt() ?? 0, // Tổng giá trị
                );

                loadedOrders.add(order);
              }
            }
          } catch (e) {
            print('Error processing order ${entry.key}: $e');
          }
        }

        // Sắp xếp theo thời gian mới nhất
        //loadedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        setState(() => orders = loadedOrders);
        print('Loaded ${loadedOrders.length} orders');
      } catch (e) {
        print('Error loading orders: $e');
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'đã giao':
        return Colors.green;
      case 'đã hủy':
        return Colors.red;
      case 'đang giao':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'đã giao':
        return Icons.check_circle;
      case 'đã hủy':
        return Icons.cancel;
      case 'đang giao':
        return Icons.local_shipping;
      default:
        return Icons.access_time;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: orders.isEmpty
          ? Center(
              child: Text('Chưa có đơn hàng nào'),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    OrderDetailScreen(order: order),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Đơn hàng ${order.id != null ? order.id.toString().padLeft(8, '0') : 'N/A'}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            order.createdAt != null
                                                ? DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt!)
                                                : 'N/A', // Hiển thị 'N/A' nếu createdAt là null
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Cửa hàng: ${order.restaurant?.name}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(
                                        locale: 'vi_VN',
                                        symbol: '₫',
                                        decimalDigits: 0,
                                      ).format(order.totalAmount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

