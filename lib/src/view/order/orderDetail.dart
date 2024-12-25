import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../model/order.dart';
import '../../view/feedback/feedbackScreen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;

  OrderDetailScreen({required this.order});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> orderItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    try {
      final snapshot =
          await _database.child('orderItems').child(widget.order.id).get();

      if (snapshot.value != null) {
        final items = (snapshot.value as Map<dynamic, dynamic>).entries;
        final List<Map<String, dynamic>> loadedItems = [];

        for (var item in items) {
          final productId = item.value['productId'];
          final productSnapshot =
              await _database.child('products').child(productId).get();

          if (productSnapshot.value != null) {
            final product = productSnapshot.value as Map<dynamic, dynamic>;
            loadedItems.add({
              'productId': productId,
              'name': product['name'],
              'price': item.value['price'],
              'quantity': item.value['quantity'],
            });
          }
        }

        setState(() {
          orderItems = loadedItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading order items: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      await _database
          .child('orders')
          .child(widget.order.id)
          .update({'status': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật trạng thái thành công')),
      );

      setState(() {
        widget.order.status = newStatus;
      });

      if (newStatus == 'đã giao') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FeedbackScreen(
              order: widget.order,
              orderItems: orderItems,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết đơn hàng'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin đơn hàng
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông tin đơn hàng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildInfoRow('Mã đơn hàng:', widget.order.id),
                          _buildInfoRow(
                            'Thời gian:',
                            DateFormat('dd/MM/yyyy HH:mm').format(
                              DateTime.fromMillisecondsSinceEpoch(
                                widget.order.createdAt,
                              ),
                            ),
                          ),
                          _buildInfoRow('Trạng thái:', widget.order.status),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

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
                          _buildInfoRow('Tên:', widget.order.recipientName),
                          _buildInfoRow(
                              'Địa chỉ:', widget.order.recipientAddress),
                          if (widget.order.note != null)
                            _buildInfoRow('Ghi chú:', widget.order.note!),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Chi tiết sản phẩm
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết sản phẩm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          ...orderItems.map((item) => Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['name']} x${item['quantity']}',
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(
                                        locale: 'vi_VN',
                                        symbol: '₫',
                                        decimalDigits: 0,
                                      ).format(
                                          item['price'] * item['quantity']),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tổng tiền:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi_VN',
                                  symbol: '₫',
                                  decimalDigits: 0,
                                ).format(widget.order.totalAmount),
                                style: TextStyle(
                                  fontSize: 16,
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

                  // Nút hành động
                  if (widget.order.status == 'đang giao')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateOrderStatus('đã hủy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: Text('Hủy đơn'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateOrderStatus('đã giao'),
                            child: Text('Đã nhận hàng'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
