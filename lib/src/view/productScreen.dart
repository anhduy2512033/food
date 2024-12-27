import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/address.dart';
import '../model/contact_information.dart';
import '../model/food.dart';
import '../model/restaurant.dart';
import '../service/ProductService.dart';
import 'order/cartScreen.dart';
import 'storeScreen.dart';
import '../service/CartService.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import '../model/order.dart';
import 'dart:typed_data';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  ProductDetailPage({Key? key, required this.productId}) : super(key: key) {
    assert(productId.isNotEmpty, 'ProductId không được để trống');
  }

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final ProductService _productService = ProductService();
  final Set<String> _expandedFeedbacks = {};

  void _toggleFeedback(String feedbackId) {
    setState(() {
      if (_expandedFeedbacks.contains(feedbackId)) {
        _expandedFeedbacks.remove(feedbackId);
      } else {
        _expandedFeedbacks.add(feedbackId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: StreamBuilder<Food>(
        stream: _productService.getProductStream(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.hasData) return Text(snapshot.data!.name ?? '');
          return const Text('Loading...');
        },
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<Food>(
      stream: _productService.getProductStream(widget.productId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(message: 'Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const LoadingIndicator();
        }

        final product = snapshot.data!;
        print('ProductDetailPage - Loaded product:');
        print('Product ID from stream: ${product.id}');
        print('Product Name: ${product.name}');

        if (product.id == null || product.id == 0) {
          return const ErrorView(message: 'Product ID không hợp lệ');
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductImageSection(product: product),
              ProductInfoSection(product: product),
              // FeedbackSection(
                //   productId: widget.productId,
                //   productService: _productService,
                //   expandedFeedbacks: _expandedFeedbacks,
                //   onToggleFeedback: _toggleFeedback,
            // ),
            ],
          ),
        );
      },
    );
  }
}

class ProductImageSection extends StatelessWidget {
  final Food product;

  const ProductImageSection({Key? key, required this.product})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Building image section for product: ${product.id}');
    print('Image URL: ${product.images}');

    if (product.images == null || product.images!.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
        ),
      );
    }

    return Container(
      height: 300,
      width: double.infinity,
      child: Image.network(
        product.images!.isNotEmpty ? product.images![0] : 'default_image_url',
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 300,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image: $error');
          return Container(
            height: 300,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.error_outline, size: 100, color: Colors.red),
            ),
          );
        },
      ),
    );
  }
}

class ProductInfoSection extends StatelessWidget {
  final Food product;
  final themeColor = Colors.orange;
  final CartService _cartService = CartService();
  final int quantity = 1;

  ProductInfoSection({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store section
          InkWell(
            onTap: () async {
              final storeSnapshot = await FirebaseDatabase.instance
                  .ref()
                  .child('stores')
                  .child(product.restaurant!.id.toString())
                  .get();
              if (storeSnapshot.exists && context.mounted) {
                final storeData =
                    Map<String, dynamic>.from(storeSnapshot.value as Map);
                storeData['id'] = product.restaurant?.id;

                final store = Restaurant(
                  id: storeData['id'],
                  name: storeData['name'],
                  description: storeData['description'] ?? '',
                  cuisineType: storeData['cuisineType'], // Nếu có
                  address: storeData['address'] != null ? Address.fromMap(storeData['address']) : null, // Nếu có
                  contactInformation: storeData['contactInformation'] != null
                      ? ContactInformation.fromMap(storeData['contactInformation'])
                      : null, // Nếu có
                  openingHours: storeData['openingHours'], // Nếu có
                  orders: storeData['orders'] != null
                      ? List<Order>.from(storeData['orders'].map((order) => Order.fromMap(order)))
                      : [], // Nếu có
                  images: storeData['images'] != null ? List<String>.from(storeData['images']) : [],
                  registrationDate: storeData['registrationDate'] != null
                      ? DateTime.parse(storeData['registrationDate'])
                      : null,
                  open: storeData['open'] ?? true, // Mặc định là true nếu không có
                  foods: storeData['foods'] != null
                      ? List<Food>.from(storeData['foods'].map((food) => Food.fromMap(food)))
                      : [], // Nếu có
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoreScreen(
                      store: store,
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    ),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Store Image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: product.restaurant?.images != null
                          ? DecorationImage(
                        image: NetworkImage(product.restaurant?.images?.first ?? 'default_image_url'),
                        fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product.restaurant?.images == null
                        ? Icon(Icons.store, color: Colors.grey[400])
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Store Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                    product.restaurant?.name ?? 'Tên cửa hàng không có sẵn',
                    style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.restaurant?.address?.id?.toString() ?? 'Địa chỉ không có sẵn',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Product Info Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name ?? 'Tên món ăn', // Đảm bảo product.name không null
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ],
                ),
              ),
              // Add to Cart IconButton
              Container(
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _addToCart(context),
                  icon: const Icon(
                    Icons.add_shopping_cart,
                    color: Colors.white,
                  ),
                  tooltip: 'Thêm vào giỏ hàng',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            product.description ?? 'Chưa có mô tả',
            style: TextStyle(
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Price
          Text(
            'Giá',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          Text(
            '${product.price?.toStringAsFixed(0)}₫',
            style: TextStyle(
              color: themeColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(BuildContext context) async {
    try {
      if (product.id == null || product.id == 0) {
        throw Exception('Product ID không hợp lệ');
      }

      await _cartService.addToCart(product, quantity);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm vào giỏ hàng'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Xem giỏ hàng',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartScreen(),
                ),
              );
            },
          ),
        ),
      );
    }
  }
}

// class FeedbackSection extends StatelessWidget {
//   final String productId;
//   final ProductService productService;
//   final Set<String> expandedFeedbacks;
//   final Function(String) onToggleFeedback;

//   const FeedbackSection({
//     Key? key,
//     required this.productId,
//     required this.productService,
//     required this.expandedFeedbacks,
//     required this.onToggleFeedback,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<List<FeedbackModel.Feedback>>(
//       stream: FirebaseDatabase.instance
//           .ref()
//           .child('feedbacks')
//           .orderByChild('productId')
//           .equalTo(productId)
//           .onValue
//           .asyncMap((event) async {
//         final feedbacks = <FeedbackModel.Feedback>[];
//         if (event.snapshot.value != null) {
//           final feedbacksMap = Map<String, dynamic>.from(
//               event.snapshot.value as Map<dynamic, dynamic>);

//           for (var entry in feedbacksMap.entries) {
//             try {
//               final feedbackData = Map<String, dynamic>.from(entry.value);
//               feedbackData['id'] = entry.key;

//               // Lấy thông tin user
//               Map<String, dynamic> userData = {
//                 'id': feedbackData['userId'],
//                 'name': 'Người dùng ẩn danh',
//                 'email': '',
//                 'phone': '',
//               };

//               if (feedbackData['userId'] != null) {
//                 final userSnapshot = await FirebaseDatabase.instance
//                     .ref()
//                     .child('users')
//                     .child(feedbackData['userId'])
//                     .get();

//                 if (userSnapshot.exists) {
//                   userData = Map<String, dynamic>.from(
//                       userSnapshot.value as Map<dynamic, dynamic>);
//                   userData['id'] = feedbackData['userId'];
//                 }
//               }

//               // Lấy thông tin product
//               final productSnapshot = await FirebaseDatabase.instance
//                   .ref()
//                   .child('products')
//                   .child(feedbackData['productId'])
//                   .get();

//               if (productSnapshot.exists) {
//                 final productData = Map<String, dynamic>.from(
//                     productSnapshot.value as Map<dynamic, dynamic>);
//                 productData['id'] = feedbackData['productId'];

//                 // Tạo feedback object
//                 feedbacks.add(FeedbackModel.Feedback.fromMap(
//                   feedbackData,
//                   userData,
//                   productData,
//                 ));
//               }
//             } catch (e) {
//               print('Error processing feedback ${entry.key}: $e');
//               continue;
//             }
//           }
//         }
//         return feedbacks;
//       }),
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           print('Error loading feedbacks: ${snapshot.error}');
//           return Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text('Lỗi khi tải đánh giá: ${snapshot.error}'),
//           );
//         }

//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }

//         final feedbacks = snapshot.data!;
//         if (feedbacks.isEmpty) {
//           return const Padding(
//             padding: EdgeInsets.all(16.0),
//             child: Center(
//               child: Text(
//                 'Chưa có đánh giá nào',
//                 style: TextStyle(color: Colors.grey),
//               ),
//             ),
//           );
//         }

//         return Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Đánh giá sản phẩm',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   Text(
//                     '${feedbacks.length} đánh giá',
//                     style: TextStyle(
//                       color: Colors.grey[600],
//                       fontSize: 16,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               ...feedbacks.map((feedback) => FeedbackItem(
//                     feedback: feedback,
//                     isExpanded: expandedFeedbacks.contains(feedback.id),
//                     onToggle: onToggleFeedback,
//                     productService: productService,
//                   )),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// class FeedbackItem extends StatelessWidget {
//   final FeedbackModel.Feedback feedback;
//   final bool isExpanded;
//   final Function(String) onToggle;
//   final ProductService productService;

//   const FeedbackItem({
//     Key? key,
//     required this.feedback,
//     required this.isExpanded,
//     required this.onToggle,
//     required this.productService,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildHeader(),
//             const SizedBox(height: 8),
//             Text(feedback.content),
//             if (feedback.image != null) ...[
//               const SizedBox(height: 8),
//               _buildImage(),
//             ],
//             const SizedBox(height: 8),
//             _buildCommentToggle(),
//             if (isExpanded) ...[
//               const SizedBox(height: 8),
//               _buildComments(),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               feedback.user.fullName,
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//             Text(
//               DateFormat('MMM dd, yyyy').format(
//                 DateTime.fromMillisecondsSinceEpoch(feedback.createdAt),
//               ),
//               style: const TextStyle(color: Colors.grey),
//             ),
//           ],
//         ),
//         Row(
//           children: List.generate(5, (index) {
//             return Icon(
//               index < feedback.rating ? Icons.star : Icons.star_border,
//               color: Colors.amber,
//               size: 16,
//             );
//           }),
//         ),
//       ],
//     );
//   }

//   Widget _buildImage() {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(8),
//       child: Image.memory(
//         base64Decode(feedback.image!.split(',').last),
//         height: 200,
//         width: double.infinity,
//         fit: BoxFit.cover,
//         errorBuilder: (context, error, stackTrace) {
//           print('Error loading feedback image: $error');
//           return Container(
//             height: 200,
//             decoration: BoxDecoration(
//               color: Colors.grey[200],
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.error_outline, size: 40, color: Colors.grey[400]),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Không thể tải hình ảnh',
//                   style: TextStyle(color: Colors.grey[600]),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildCommentToggle() {
//     return InkWell(
//       onTap: () => onToggle(feedback.id),
//       child: Row(
//         children: [
//           const Icon(
//             Icons.comment,
//             size: 16,
//             color: Colors.blue,
//           ),
//           const SizedBox(width: 4),
//           StreamBuilder<List<FeedbackComment>>(
//             stream: productService.getFeedbackComments(feedback.id),
//             builder: (context, snapshot) {
//               final commentCount = snapshot.data?.length ?? 0;
//               return Text(
//                 '$commentCount Comments',
//                 style: const TextStyle(color: Colors.blue),
//               );
//             },
//           ),
//           Icon(
//             isExpanded ? Icons.expand_less : Icons.expand_more,
//             color: Colors.blue,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildComments() {
//     return StreamBuilder<List<FeedbackComment>>(
//       stream: productService.getFeedbackComments(feedback.id),
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return Text('Error: ${snapshot.error}');
//         }

//         if (!snapshot.hasData) {
//           return const Center(
//             child: CircularProgressIndicator(),
//           );
//         }

//         final comments = snapshot.data!;
//         if (comments.isEmpty) {
//           return const Center(
//             child: Text(
//               'No comments yet',
//               style: TextStyle(color: Colors.grey),
//             ),
//           );
//         }

//         return ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: comments.length,
//           itemBuilder: (context, index) => CommentItem(
//             comment: comments[index],
//             isLast: index == comments.length - 1,
//           ),
//         );
//       },
//     );
//   }
// }

// class CommentItem extends StatelessWidget {
//   final FeedbackComment comment;
//   final bool isLast;

//   const CommentItem({
//     Key? key,
//     required this.comment,
//     required this.isLast,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(left: 16.0, top: 8.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               CircleAvatar(
//                 radius: 12,
//                 backgroundColor: Colors.grey[200],
//                 child: Text(
//                   comment.user.fullName[0].toUpperCase(),
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.grey[800],
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Text(
//                           comment.user.fullName,
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         const SizedBox(width: 8),
//                         Text(
//                           DateFormat('MMM dd, yyyy').format(
//                             DateTime.fromMillisecondsSinceEpoch(
//                                 comment.createdAt),
//                           ),
//                           style: const TextStyle(
//                             color: Colors.grey,
//                             fontSize: 12,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 4),
//                     Text(comment.content),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           if (!isLast) Divider(height: 16, color: Colors.grey[300]),
//         ],
//       ),
//     );
//   }
// }

// Thêm các widgets tiện ích
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;

  const ErrorView({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}
