import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import '../../model/order.dart';

class FeedbackScreen extends StatefulWidget {
  final Order order;
  final List<Map<String, dynamic>> orderItems;

  FeedbackScreen({required this.order, required this.orderItems});

  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _database = FirebaseDatabase.instance.ref();
  final _imagePicker = ImagePicker();

  final Map<String, double> _ratings = {};
  final Map<String, TextEditingController> _contentControllers = {};
  final Map<String, File?> _selectedImages = {};
  final Map<String, String> _base64Images = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.orderItems) {
      _ratings[item['name']] = 5.0;
      _contentControllers[item['name']] = TextEditingController();
    }
  }

  Future<void> _pickImage(String productName) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      final File imageFile = File(pickedFile.path);
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final int sizeInBytes = base64Image.length;
      final double sizeInMB = sizeInBytes / (1024 * 1024);

      if (sizeInMB > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn')),
        );
        return;
      }

      setState(() {
        _selectedImages[productName] = imageFile;
        _base64Images[productName] = 'data:image/jpeg;base64,$base64Image';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn ảnh: $e')),
      );
    }
  }

  Future<void> _submitFeedback() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Vui lòng đăng nhập lại');

      for (var item in widget.orderItems) {
        print('Item data: ${item.toString()}');
        print('Available keys: ${item.keys.toList()}');

        final productId = item['productId'] ??
            item['product_id'] ??
            item['id'] ??
            item['product']?['id'];

        if (productId == null) {
          print('ProductId is null. Item structure: $item');
          throw Exception('Không tìm thấy ID sản phẩm');
        }

        print('Found productId: $productId');

        final rating = _ratings[item['name']] ?? 5.0;
        final content = _contentControllers[item['name']]?.text ?? '';

        if (content.isEmpty) {
          throw Exception('Vui lòng nhập đánh giá cho tất cả sản phẩm');
        }

        Map<String, dynamic> feedbackData = {
          'userId': currentUser.uid,
          'productId': productId,
          'rating': rating,
          'content': content,
          'createdAt': ServerValue.timestamp,
        };

        print('Preparing to submit feedback: $feedbackData');

        if (_base64Images.containsKey(item['name'])) {
          feedbackData['image'] = _base64Images[item['name']];
        }

        try {
          await _database.child('feedbacks').push().set(feedbackData);
          print('Feedback submitted successfully for product: $productId');

          DataSnapshot feedbacksSnapshot = await _database
              .child('feedbacks')
              .orderByChild('productId')
              .equalTo(productId)
              .get();

          if (feedbacksSnapshot.value != null) {
            Map<dynamic, dynamic> feedbacks =
                Map<dynamic, dynamic>.from(feedbacksSnapshot.value as Map);

            double totalRating = 0;
            feedbacks.forEach((key, value) {
              totalRating += (value['rating'] as num).toDouble();
            });

            double averageRating = totalRating / feedbacks.length;

            await _database
                .child('products')
                .child(productId)
                .update({'rating': averageRating});
          }
        } catch (e) {
          print('Lỗi khi xử lý feedback cho sản phẩm $productId: $e');
          continue;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đánh giá thành công!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đánh giá sản phẩm'),
      ),
      body: _isSubmitting
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  ...widget.orderItems
                      .map((item) => Card(
                            margin: EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: List.generate(5, (index) {
                                      return IconButton(
                                        icon: Icon(
                                          index <
                                                  (_ratings[item['name']] ?? 5)
                                                      .floor()
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _ratings[item['name']] =
                                                index + 1.0;
                                          });
                                        },
                                      );
                                    }),
                                  ),
                                  SizedBox(height: 16),
                                  TextField(
                                    controller:
                                        _contentControllers[item['name']],
                                    decoration: InputDecoration(
                                      hintText: 'Nhập đánh giá của bạn',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 3,
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _pickImage(item['name']),
                                        icon: Icon(Icons.camera_alt),
                                        label: Text('Thêm ảnh'),
                                      ),
                                      if (_selectedImages[item['name']] !=
                                          null) ...[
                                        SizedBox(width: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            _selectedImages[item['name']]!,
                                            height: 60,
                                            width: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              _selectedImages[item['name']] =
                                                  null;
                                              _base64Images
                                                  .remove(item['name']);
                                            });
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitFeedback,
                      child: Text(
                        'Gửi đánh giá',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _contentControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}
