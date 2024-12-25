import 'package:firebase_database/firebase_database.dart';
import '../model/feedback.dart' as FeedbackModel;
import '../model/category.dart';
import '../model/feedback_comment.dart';
import '../model/product.dart';
import '../model/store.dart';
import '../model/user.dart';

class ProductService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Cache maps
  final Map<String, Store> _storeCache = {};
  final Map<String, Category> _categoryCache = {};
  final Map<String, User> _userCache = {};

  Future<User> _getUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    final snapshot = await _dbRef.child('users/$userId').get();
    final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
    // Pass userId separately as User.fromMap requires
    final user = User.fromMap(userId, data);
    _userCache[userId] = user;
    return user;
  }

  Stream<Product> getProductStream(String productId) {
    print('ProductService - Getting product stream for ID: $productId');
    
    return _dbRef.child('products/$productId').onValue.map((event) async {
      if (event.snapshot.value == null) {
        throw Exception('Product not found');
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('Raw data from Firebase: $data');

      // Sửa lại cách lấy storeId và categoryId
      final storeId = data['storeId']?.toString() ?? ''; // Thay đổi từ store_id thành storeId
      final categoryId = data['categoryId']?.toString() ?? ''; // Thay đổi từ category_id thành categoryId

      print('Store ID from data: $storeId');
      print('Category ID from data: $categoryId');

      if (storeId.isEmpty || categoryId.isEmpty) {
        throw Exception('Missing store or category information');
      }

      Store store;
      Category category;

      try {
        // Lấy thông tin store
        final storeSnapshot = await _dbRef.child('stores/$storeId').get();
        if (storeSnapshot.value != null) {
          final storeData = Map<String, dynamic>.from(storeSnapshot.value as Map);
          store = Store(
            id: storeId,
            name: storeData['name']?.toString() ?? '',
            description: storeData['description']?.toString() ?? '',
            phoneNumber: storeData['phoneNumber']?.toString() ?? '',
            address: storeData['address']?.toString() ?? '',
            status: storeData['status']?.toString() ?? '',
            rating: (storeData['rating'] as num?)?.toDouble() ?? 0,
          );
        } else {
          throw Exception('Store not found');
        }

        // Lấy thông tin category
        final categorySnapshot = await _dbRef.child('categories/$categoryId').get();
        if (categorySnapshot.value != null) {
          final categoryData = Map<String, dynamic>.from(categorySnapshot.value as Map);
          category = Category(
            id: categoryId,
            name: categoryData['name']?.toString() ?? '',
            description: categoryData['description']?.toString() ?? '',
          );
        } else {
          throw Exception('Category not found');
        }

      } catch (e) {
        print('Error getting store or category: $e');
        rethrow;
      }

      return Product(
        id: productId,
        name: data['name']?.toString() ?? '',
        price: (data['price'] as num?)?.toDouble() ?? 0,
        description: data['description']?.toString() ?? '',
        status: data['status']?.toString() ?? '',
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
        image: data['image']?.toString() ?? '',
        thumbnail: data['thumbnail']?.toString() ?? '',
        store: store,
        category: category,
      );
    }).asyncMap((future) => future);
  }

  Stream<List<FeedbackModel.Feedback>> getProductFeedbacks(String productId) {
    return _dbRef
        .child('feedbacks')
        .orderByChild('productId')
        .equalTo(productId)
        .onValue
        .map<Future<List<FeedbackModel.Feedback>>>((event) async {
      if (event.snapshot.value == null) return [];

      final Map<String, dynamic> feedbacksData =
      Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<FeedbackModel.Feedback> feedbacks = [];

      for (var entry in feedbacksData.entries) {
        final String feedbackId = entry.key;
        final Map<String, dynamic> data = Map<String, dynamic>.from(entry.value as Map);

        try {
          final userId = data['userId'] as String;
          final user = await _getUser(userId);
          final product = await _getProduct(productId);

          feedbacks.add(FeedbackModel.Feedback.fromMap(
            {...data, 'id': feedbackId},
            <String, User>{userId: user},
            <String, Product>{productId: product},
          ));
        } catch (e) {
          print('Error processing feedback $feedbackId: $e');
          continue;
        }
      }

      return feedbacks;
    }).asyncMap((future) => future);
  }

  Stream<List<FeedbackComment>> getFeedbackComments(String feedbackId) {
    return _dbRef
        .child('feedback_comments')
        .orderByChild('feedbackId')
        .equalTo(feedbackId)
        .onValue
        .map<Future<List<FeedbackComment>>>((event) async {
      if (event.snapshot.value == null) return [];

      final Map<String, dynamic> commentsData =
      Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<FeedbackComment> comments = [];

      for (var entry in commentsData.entries) {
        final String commentId = entry.key;
        final Map<String, dynamic> data = Map<String, dynamic>.from(entry.value as Map);

        try {
          final userId = data['userId'] as String;
          final user = await _getUser(userId);
          final feedback = await _getFeedback(feedbackId);

          comments.add(FeedbackComment.fromMap(
            {...data, 'id': commentId},
            <String, User>{userId: user},
            <String, FeedbackModel.Feedback>{feedbackId: feedback},
          ));
        } catch (e) {
          print('Error processing comment $commentId: $e');
          continue;
        }
      }

      return comments;
    }).asyncMap((future) => future);
  }

  Future<Store> _getStore(String storeId) async {
    if (_storeCache.containsKey(storeId)) {
      return _storeCache[storeId]!;
    }

    final snapshot = await _dbRef.child('stores/$storeId').get();
    if (snapshot.value == null) {
      throw Exception('Store not found');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
    final store = Store.fromMap({...data, 'id': storeId});
    _storeCache[storeId] = store;
    return store;
  }

  Future<Category> _getCategory(String categoryId) async {
    if (_categoryCache.containsKey(categoryId)) {
      return _categoryCache[categoryId]!;
    }

    final snapshot = await _dbRef.child('categories/$categoryId').get();
    if (snapshot.value == null) {
      throw Exception('Category not found');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
    final category = Category.fromMap({...data, 'id': categoryId});
    _categoryCache[categoryId] = category;
    return category;
  }

  Future<Product> _getProduct(String productId) async {
    final snapshot = await _dbRef.child('products/$productId').get();
    if (snapshot.value == null) {
      throw Exception('Product not found');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
    final store = await _getStore(data['storeId'] as String);
    final category = await _getCategory(data['categoryId'] as String);

    return Product.fromMap(
      {...data, 'id': productId},
      <String, Store>{store.id: store},
      <String, Category>{category.id: category},
    );
  }

  Future<FeedbackModel.Feedback> _getFeedback(String feedbackId) async {
    final snapshot = await _dbRef.child('feedbacks/$feedbackId').get();
    if (snapshot.value == null) {
      throw Exception('Feedback not found');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
    final user = await _getUser(data['userId'] as String);
    final product = await _getProduct(data['productId'] as String);

    return FeedbackModel.Feedback.fromMap(
      {...data, 'id': feedbackId},
      <String, User>{user.id: user},
      <String, Product>{product.id: product},
    );
  }

  Future<Product> getProduct(String productId) async {
    try {
      print('Getting product with ID: $productId'); // Debug log

      final snapshot = await _dbRef
          .child('products')
          .child(productId)
          .get();

      if (snapshot.value == null) {
        throw Exception('Không tìm thấy sản phẩm');
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      print('Product data from Firebase: $data'); // Debug log

      // Kiểm tra và xử lý dữ liệu null
      final storeId = data['store_id']?.toString() ?? '';
      final categoryId = data['category_id']?.toString() ?? '';

      // Lấy thông tin store nếu có storeId
      Store store = Store(
        id: storeId,
        name: '',
        description: '',
        phoneNumber: '',
        address: '',
        status: '',
        rating: 0,
      );

      if (storeId.isNotEmpty) {
        try {
          final storeSnapshot = await _dbRef
              .child('stores')
              .child(storeId)
              .get();
          
          if (storeSnapshot.value != null) {
            final storeData = Map<dynamic, dynamic>.from(storeSnapshot.value as Map);
            store = Store(
              id: storeId,
              name: storeData['name']?.toString() ?? '',
              description: storeData['description']?.toString() ?? '',
              phoneNumber: storeData['phone_number']?.toString() ?? '',
              address: storeData['address']?.toString() ?? '',
              status: storeData['status']?.toString() ?? '',
              rating: (storeData['rating'] as num?)?.toDouble() ?? 0,
            );
          }
        } catch (e) {
          print('Error loading store data: $e');
        }
      }

      // Lấy thông tin category nếu có categoryId
      Category category = Category(
        id: categoryId,
        name: '',
        description: '',
      );

      if (categoryId.isNotEmpty) {
        try {
          final categorySnapshot = await _dbRef
              .child('categories')
              .child(categoryId)
              .get();
          
          if (categorySnapshot.value != null) {
            final categoryData = Map<dynamic, dynamic>.from(categorySnapshot.value as Map);
            category = Category(
              id: categoryId,
              name: categoryData['name']?.toString() ?? '',
              description: categoryData['description']?.toString() ?? '',
            );
          }
        } catch (e) {
          print('Error loading category data: $e');
        }
      }

      return Product(
        id: productId,
        name: data['name']?.toString() ?? '',
        price: (data['price'] as num?)?.toDouble() ?? 0,
        description: data['description']?.toString() ?? '',
        status: data['status']?.toString() ?? '',
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
        image: data['image']?.toString() ?? '',
        thumbnail: data['thumbnail']?.toString() ?? '',
        store: store,
        category: category,
      );
    } catch (e) {
      print('Error getting product: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }
}
