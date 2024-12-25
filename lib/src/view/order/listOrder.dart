import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../model/order.dart';
import '../../model/user.dart' as app_user;
import '../../model/store.dart';
import 'orderDetail.dart';

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
        final stores = <String, Store>{};

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
            stores[key.toString()] = Store(
              id: key.toString(),
              name: value['name'] ?? '',
              description: value['description'] ?? '',
              phoneNumber: value['phoneNumber'] ?? '',
              address: value['address'] ?? '',
              status: value['status'] ?? '',
              rating: (value['rating'] as num?)?.toDouble() ?? 0.0,
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
                  id: entry.key,
                  user: user,
                  store: store,
                  note: orderData['note']?.toString(),
                  status: orderData['status']?.toString() ?? '',
                  paymentMethod: PaymentMethod.cashOnDelivery,
                  totalAmount: (orderData['totalAmount'] as num).toDouble(),
                  shippingFee:
                      (orderData['shippingFee'] as num?)?.toDouble() ?? 0.0,
                  recipientName: orderData['recipientName']?.toString() ?? '',
                  recipientAddress:
                      orderData['recipientAddress']?.toString() ?? '',
                  createdAt: orderData['createdAt'] as int,
                );
                loadedOrders.add(order);
              }
            }
          } catch (e) {
            print('Error processing order ${entry.key}: $e');
          }
        }

        // Sắp xếp theo thời gian mới nhất
        loadedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                final statusColor = _getStatusColor(order.status);
                final statusIcon = _getStatusIcon(order.status);

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
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        statusIcon,
                                        color: statusColor,
                                        size: 24,
                                      ),
                                    ),
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
                                                'Đơn hàng ${order.id.substring(0, 8)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  order.status,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            DateFormat('dd/MM/yyyy HH:mm')
                                                .format(DateTime
                                                    .fromMillisecondsSinceEpoch(
                                                        order.createdAt)),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
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
                                      'Cửa hàng: ${order.store.name}',
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
