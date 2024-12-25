import 'cart.dart';
import 'feedback.dart';
import 'order.dart';
import 'product.dart';
import 'store.dart';
import 'user.dart';

class CartItem {
  final String id;
  final Cart cart; // Cart object instead of cartId
  final Product product; // Product object instead of productId and productName
  final int quantity;
  final double price;
  final int createdAt;

  // Optional fields
  final Feedback? feedback; // Feedback object instead of feedbackId
  final Order? order; // Order object instead of orderId
  final Store? store; // Store object instead of storeId
  final User? user; // User object instead of userId

  CartItem({
    required this.id,
    required this.cart,
    required this.product,
    required this.quantity,
    required this.price,
    required this.createdAt,
    this.feedback,
    this.order,
    this.store,
    this.user,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cartId': cart.id, // Store cart ID
      'productId': product.id, // Store product ID
      'productName': product.name, // Store product name
      'quantity': quantity,
      'price': price,
      'createdAt': createdAt,
      'feedbackId': feedback?.id, // Store feedback ID if available
      'orderId': order?.id, // Store order ID if available
      'storeId': store?.id, // Store store ID if available
      'userId': user?.id, // Store user ID if available
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map,
      {required Map<String, Cart> carts,
      required Map<String, Product> products,
      required Map<String, Feedback> feedbacks,
      required Map<String, Order> orders,
      required Map<String, Store> stores,
      required Map<String, User> users}) {
    return CartItem(
      id: map['id'] as String,
      cart: carts[map['cartId']]!, // Retrieve Cart object
      product: products[map['productId']]!, // Retrieve Product object
      quantity: map['quantity'] as int,
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0.0,
      createdAt: map['createdAt'] as int,
      feedback: feedbacks[map['feedbackId']], // Retrieve Feedback object if available
      order: orders[map['orderId']], // Retrieve Order object if available
      store: stores[map['storeId']], // Retrieve Store object if available
      user: users[map['userId']], // Retrieve User object if available
    );
  }
}