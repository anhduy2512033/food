import 'package:firebase_database/firebase_database.dart';
import '../model/address.dart';
import '../model/category.dart';
import '../model/contact_information.dart';
import '../model/food.dart';
import '../model/ingredients_item.dart';
import '../model/restaurant.dart';
import '../model/user.dart';
import '../model/order.dart';

class ProductService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Cache maps
  final Map<String, Restaurant> _storeCache = {};
  final Map<String, Category> _categoryCache = {};
  final Map<String, User> _userCache = {};

  Future<User> _getUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    final snapshot = await _dbRef.child('users/$userId').get();
    final Map<String, dynamic> data = Map<String, dynamic>.from(
        snapshot.value as Map);
    // Pass userId separately as User.fromMap requires
    final user = User.fromMap({
      'id': userId,
      ...data,
    });
    _userCache[userId] = user;
    return user;
  }

  Stream<Food> getFoodStream(String foodId) {
    print('FoodService - Getting food stream for ID: $foodId');

    return _dbRef
        .child('foods/$foodId')
        .onValue
        .map((event) async {
      if (event.snapshot.value == null) {
        throw Exception('Food not found');
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(
          event.snapshot.value as Map);
      print('Raw data from Firebase: $data');

      // Lấy thông tin categoryId
      final categoryId = data['categoryId']?.toString() ??
          ''; // Đảm bảo đổi từ `category_id` thành `categoryId`

      print('Category ID from data: $categoryId');

      if (categoryId.isEmpty) {
        throw Exception('Missing category information');
      }

      Category foodCategory;

      try {
        final categorySnapshot = await _dbRef.child('categories/$categoryId')
            .get();
        if (categorySnapshot.value != null) {
          final categoryData = Map<String, dynamic>.from(
              categorySnapshot.value as Map);
          foodCategory = Category(
            id: categoryData['id'] as int?,
            name: categoryData['name']?.toString() ?? 'Danh mục không xác định',
            restaurant: categoryData['restaurant'] != null
                ? Restaurant.fromMap(
                Map<String, dynamic>.from(categoryData['restaurant'] as Map))
                : null,
          );
        } else {
          throw Exception('Category not found');
        }
      } catch (e) {
        print('Error getting category: $e');
        rethrow;
      }


      return Food(
        id: data['id'] as int?,
        name: data['name']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        price: (data['price'] as num?)?.toInt() ?? 0,
        foodCategory: foodCategory,
        images: data['images'] != null ? List<String>.from(data['images']) : [],
        available: data['available'] as bool? ?? false,
        isVegetarian: data['isVegetarian'] as bool? ?? false,
        isSeasonal: data['isSeasonal'] as bool? ?? false,
        ingredients: data['ingredients'] != null
            ? List<IngredientsItem>.from(
            data['ingredients'].map((item) => IngredientsItem.fromMap(item)))
            : [],
        creationDate: data['creationDate'] != null ? DateTime.parse(
            data['creationDate']) : null,
        restaurant: data['restaurant'] != null
            ? Restaurant.fromMap(Map<String, dynamic>.from(data['restaurant']))
            : null,
      );
    }).asyncMap((future) => future);
  }

  Future<Restaurant> _getStore(String storeId) async {
    if (_storeCache.containsKey(storeId)) {
      return _storeCache[storeId]!;
    }

    final snapshot = await _dbRef.child('stores/$storeId').get();
    if (snapshot.value == null) {
      throw Exception('Store not found');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(
        snapshot.value as Map);
    final store = Restaurant.fromMap({...data, 'id': storeId});
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

    final Map<String, dynamic> data = Map<String, dynamic>.from(
        snapshot.value as Map);
    final category = Category.fromMap({...data, 'id': categoryId});
    _categoryCache[categoryId] = category;
    return category;
  }

  Future<Food> _getFood(String foodId) async {
    // Lấy dữ liệu món ăn từ Firebase
    final snapshot = await _dbRef.child('foods/$foodId').get();
    if (snapshot.value == null) {
      throw Exception('Food not found');
    }

    // Chuyển đổi dữ liệu thành Map
    final Map<String, dynamic> data = Map<String, dynamic>.from(
        snapshot.value as Map);

    // Lấy thông tin nhà hàng (Restaurant)
    final restaurant = await _getStore(data['restaurantId'] as String);

    // Lấy thông tin danh mục (Category)
    final category = await _getCategory(data['categoryId'] as String);

    // Tạo đối tượng Food từ dữ liệu và thông tin liên quan
    return Food.fromMap({
      ...data,
      'id': foodId,
      'restaurant': restaurant.toMap(),
      'foodCategory': category.toMap(),
    });
  }
  Future<Food> getFood(String foodId) async {
    try {
      print('Getting food with ID: $foodId'); // Debug log

      final snapshot = await _dbRef
          .child('foods') // Đường dẫn Firebase phù hợp với Food
          .child(foodId)
          .get();

      if (snapshot.value == null) {
        throw Exception('Không tìm thấy món ăn');
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      print('Food data from Firebase: $data'); // Debug log

      // Kiểm tra và xử lý dữ liệu null
      final restaurantId = data['restaurant_id']?.toString() ?? '';
      final categoryId = data['category_id']?.toString() ?? '';

      // Khởi tạo restaurant mặc định
      Restaurant restaurant = Restaurant(
        id: restaurantId.isNotEmpty ? int.tryParse(restaurantId) : null,
        owner: null,
        name: '',
        description: '',
        cuisineType: '',
        address: null,
        contactInformation: null,
        openingHours: '',
        orders: [],
        images: [],
        registrationDate: DateTime.now(),
        open: true,
        foods: [],
      );

      if (restaurantId.isNotEmpty) {
        try {
          final restaurantSnapshot = await _dbRef
              .child('restaurants') // Lấy thông tin từ restaurants
              .child(restaurantId)
              .get();

          if (restaurantSnapshot.value != null) {
            final restaurantData = Map<String, dynamic>.from(restaurantSnapshot.value as Map);

            restaurant = Restaurant(
              id: int.tryParse(restaurantId) ?? 0,
              owner: restaurantData['owner'] != null
                  ? User.fromMap(Map<String, dynamic>.from(restaurantData['owner']))
                  : null,
              name: restaurantData['name']?.toString() ?? '',
              description: restaurantData['description']?.toString() ?? '',
              cuisineType: restaurantData['cuisineType']?.toString() ?? '',
              address: restaurantData['address'] != null
                  ? Address.fromMap(Map<String, dynamic>.from(restaurantData['address']))
                  : null,
              contactInformation: restaurantData['contactInformation'] != null
                  ? ContactInformation.fromMap(Map<String, dynamic>.from(restaurantData['contactInformation']))
                  : null,
              openingHours: restaurantData['openingHours']?.toString() ?? '',
              orders: restaurantData['orders'] != null
                  ? List<Order>.from(restaurantData['orders'].map((order) => Order.fromMap(Map<String, dynamic>.from(order))))
                  : [],
              images: restaurantData['images'] != null
                  ? List<String>.from(restaurantData['images'])
                  : [],
              registrationDate: restaurantData['registrationDate'] != null
                  ? DateTime.parse(restaurantData['registrationDate'])
                  : DateTime.now(),
              open: restaurantData['open'] ?? true,
              foods: restaurantData['foods'] != null
                  ? List<Food>.from(restaurantData['foods'].map((food) => Food.fromMap(Map<String, dynamic>.from(food))))
                  : [],
            );
          }
        } catch (e) {
          print('Error loading restaurant data: $e');
        }
      }

      // Khởi tạo category mặc định
      Category category = Category(
        id: int.tryParse(categoryId) ?? 0,
        name: '',
        restaurant: null,
      );

      if (categoryId.isNotEmpty) {
        try {
          final categorySnapshot = await _dbRef
              .child('categories')
              .child(categoryId)
              .get();

          if (categorySnapshot.value != null) {
            final categoryData = Map<String, dynamic>.from(categorySnapshot.value as Map);

            category = Category.fromMap({
              'id': int.tryParse(categoryId) ?? 0,
              'name': categoryData['name']?.toString() ?? '',
              'restaurant': restaurant != null ? restaurant.toMap() : null,
            });
          }
        } catch (e) {
          print('Error loading category data: $e');
        }
      }

      return Food(
        id: int.tryParse(foodId) ?? 0,
        name: data['name']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        price: (data['price'] as num?)?.toInt() ?? 0,
        foodCategory: data['foodCategory'] != null
            ? Category.fromMap(data['foodCategory'])
            : null,
        images: data['images'] != null
            ? List<String>.from(data['images'])
            : [],
        available: data['available'] ?? false,
        restaurant: data['restaurant'] != null
            ? Restaurant.fromMap(data['restaurant'])
            : null,
        isVegetarian: data['isVegetarian'] ?? false,
        isSeasonal: data['isSeasonal'] ?? false,
        ingredients: data['ingredients'] != null
            ? List<IngredientsItem>.from(
            data['ingredients'].map((item) => IngredientsItem.fromMap(item)))
            : [],
        creationDate: data['creationDate'] != null
            ? DateTime.parse(data['creationDate'])
            : null,
      );
    } catch (e) {
      print('Error getting food: $e');
      rethrow;
    }
  }

  getProductStream(String productId) {}
}