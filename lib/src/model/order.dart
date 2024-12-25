import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_application_2/src/model/restaurant.dart';
import 'user.dart';
import 'address.dart';
import 'order_item.dart';


class Order {
  int? id;
  User? customer; // Mối quan hệ với User
  Restaurant? restaurant; // Mối quan hệ với Restaurant
  int? totalAmount; // Tổng số tiền (thay Long bằng int)
  String? orderStatus; // Trạng thái đơn hàng
  DateTime? createdAt; // Ngày tạo đơn hàng (thay Date bằng DateTime)
  Address? deliveryAddress; // Mối quan hệ với Address
  List<OrderItem>? items; // Danh sách các sản phẩm trong đơn hàng
  int? totalItem; // Tổng số sản phẩm
  int? totalPrice; // Tổng giá trị đơn hàng

  Order({
    this.id,
    this.customer,
    this.restaurant,
    this.totalAmount,
    this.orderStatus,
    this.createdAt,
    this.deliveryAddress,
    this.items,
    this.totalItem,
    this.totalPrice,
  });

  // Tạo đối tượng Order từ Map
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      customer: map['customer'] != null ? User.fromMap(map['customer']) : null,
      restaurant: map['restaurant'] != null ? Restaurant.fromMap(map['restaurant']) : null,
      totalAmount: map['totalAmount'],
      orderStatus: map['orderStatus'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      deliveryAddress: map['deliveryAddress'] != null ? Address.fromMap(map['deliveryAddress']) : null,
      items: map['items'] != null
          ? List<OrderItem>.from(map['items'].map((item) => OrderItem.fromMap(item)))
          : [],
      totalItem: map['totalItem'],
      totalPrice: map['totalPrice'],
    );
  }

  // Chuyển đối tượng Order thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer': customer?.toMap(),
      'restaurant': restaurant?.toMap(),
      'totalAmount': totalAmount,
      'orderStatus': orderStatus,
      'createdAt': createdAt?.toIso8601String(),
      'deliveryAddress': deliveryAddress?.toMap(),
      'items': items?.map((item) => item.toMap()).toList(),
      'totalItem': totalItem,
      'totalPrice': totalPrice,
    };
  }
}