import 'user.dart';
import 'store.dart';

// Enum for payment methods
enum PaymentMethod {
  cashOnDelivery, // Trả khi nhận hàng
}

class Order {
  String id;
  User user;
  Store store;
  String? note; // Ghi chú
  String status; // Trạng thái: "chưa nhận", "đã nhận", "đã hủy", v.v.
  PaymentMethod paymentMethod; // Hình thức thanh toán
  double totalAmount; // Tổng tiền
  double shippingFee; // Phí vận chuyển
  String recipientName; // Tên người nhận
  String recipientAddress; // Địa chỉ người nhận
  int createdAt;

  Order({
    required this.id,
    required this.user,
    required this.store,
    this.note,
    required this.status,
    this.paymentMethod = PaymentMethod.cashOnDelivery,
    required this.totalAmount,
    required this.shippingFee,
    required this.recipientName,
    required this.recipientAddress,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': user.id,
      'storeId': store.id,
      'note': note,
      'status': status,
      'paymentMethod': paymentMethod.toString(),
      'totalAmount': totalAmount,
      'shippingFee': shippingFee,
      'recipientName': recipientName,
      'recipientAddress': recipientAddress,
      'createdAt': createdAt,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory Order.fromMap(
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
      throw Exception('User or Store not found for order ${map['id']}');
    }

    return Order(
      id: map['id']?.toString() ?? '',
      user: user,
      store: store,
      note: map['note']?.toString(),
      status: map['status']?.toString() ?? '',
      paymentMethod: map['paymentMethod'] != null
          ? PaymentMethod.values.firstWhere(
              (e) => e.toString() == map['paymentMethod'],
              orElse: () => PaymentMethod.cashOnDelivery)
          : PaymentMethod.cashOnDelivery,
      totalAmount: _parseDouble(map['totalAmount']),
      shippingFee: _parseDouble(map['shippingFee']),
      recipientName: map['recipientName']?.toString() ?? '',
      recipientAddress: map['recipientAddress']?.toString() ?? '',
      createdAt: map['createdAt'] as int,
    );
  }
}
