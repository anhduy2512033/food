import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../model/category.dart';
import '../model/product.dart';
import '../model/store.dart';
import 'productScreen.dart';

class StoreScreen extends StatefulWidget {
  final Store store;
  final String userId; // Add userId parameter

  const StoreScreen({
    Key? key,
    required this.store,
    required this.userId,
  }) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Product> storeProducts = [];
  bool isLoading = true;
  bool isFavorite = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadStoreProducts();
    _checkFavoriteStatus();
  }

  Future<void> _toggleFavorite() async {
    try {
      // Lấy current user ID từ Firebase Auth
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để thực hiện chức năng này'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final String userId = currentUser.uid;
      print('Current UserId: $userId'); // Check userId
      print('StoreId: ${widget.store.id}'); // Check storeId

      if (isFavorite) {
        // Find and remove the favorite
        final favoriteSnapshot = await _database
            .child('favorites')
            .orderByChild('userId')
            .equalTo(userId)  // Sử dụng userId từ currentUser
            .get();

        print('Favorite Snapshot exists: ${favoriteSnapshot.exists}');
        print('Favorite Snapshot value: ${favoriteSnapshot.value}');

        if (favoriteSnapshot.exists && favoriteSnapshot.value != null) {
          final favoritesData = Map<String, dynamic>.from(favoriteSnapshot.value as Map);
          final favoriteId = favoritesData.entries
              .firstWhere((entry) =>
          entry.value['storeId'] == widget.store.id)
              .key;

          print('Removing favorite with ID: $favoriteId');
          await _database.child('favorites').child(favoriteId).remove();
        }
      } else {
        // Add new favorite
        final newFavoriteRef = _database.child('favorites').push();
        print('Adding new favorite with reference: ${newFavoriteRef.key}');

        await newFavoriteRef.set({
          'userId': userId,  // Sử dụng userId từ currentUser
          'storeId': widget.store.id,
          'timestamp': ServerValue.timestamp,
        });
      }

      setState(() {
        isFavorite = !isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isFavorite
                  ? 'Đã thêm cửa hàng vào danh sách yêu thích'
                  : 'Đã xóa cửa hàng khỏi danh sách yêu thích'
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error details: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Có lỗi xảy ra. Vui lòng thử lại sau.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final String userId = currentUser.uid;
      print('Checking favorite status for userId: $userId');

      final favoriteSnapshot = await _database
          .child('favorites')
          .orderByChild('userId')
          .equalTo(userId)  // Sử dụng userId từ currentUser
          .get();

      print('Favorite check snapshot exists: ${favoriteSnapshot.exists}');
      print('Favorite check snapshot value: ${favoriteSnapshot.value}');

      if (favoriteSnapshot.exists && favoriteSnapshot.value != null) {
        final favoritesData = Map<String, dynamic>.from(favoriteSnapshot.value as Map);

        setState(() {
          isFavorite = favoritesData.values.any((favorite) =>
          favorite['storeId'] == widget.store.id);
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
    }
  }

  Future<void> _loadStoreProducts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final productsSnapshot = await _database
          .child('products')
          .orderByChild('storeId')
          .equalTo(widget.store.id)
          .get();

      if (productsSnapshot.exists && productsSnapshot.value != null) {
        final productsData = Map<String, dynamic>.from(productsSnapshot.value as Map);

        // Get categories for product mapping
        final categoriesSnapshot = await _database.child('categories').get();
        final Map<String, dynamic> categoriesData =
        categoriesSnapshot.exists && categoriesSnapshot.value != null
            ? Map<String, dynamic>.from(categoriesSnapshot.value as Map)
            : {};

        // Create maps for fromMap factory
        final Map<String, Store> storesMap = {widget.store.id: widget.store};
        final Map<String, Category> categoriesMap = {};

        // Process categories
        categoriesData.forEach((key, value) {
          if (value is Map) {
            final categoryData = Map<String, dynamic>.from(value);
            categoryData['id'] = key;
            categoriesMap[key] = Category.fromMap(categoryData);
          }
        });

        // Process products
        final List<Product> products = [];
        productsData.forEach((key, value) {
          try {
            if (value is Map) {
              final productData = Map<String, dynamic>.from(value);
              productData['id'] = key;
              final product = Product.fromMap(productData, storesMap, categoriesMap);
              products.add(product);
            }
          } catch (e) {
            print('Error processing product $key: $e');
          }
        });

        // Sort products by rating
        products.sort((a, b) => b.rating.compareTo(a.rating));

        setState(() {
          storeProducts = products;
          isLoading = false;
        });
      } else {
        setState(() {
          storeProducts = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Có lỗi xảy ra khi tải dữ liệu: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Store Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.store.image != null
                  ? Image.network(
                widget.store.image!,
                fit: BoxFit.cover,
              )
                  : Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.store,
                  size: 80,
                  color: Colors.orange[800],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),

          // Store Information
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.store.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.store.status.toLowerCase() == 'open'
                              ? Colors.green[50]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.store.status,
                          style: TextStyle(
                            color: widget.store.status.toLowerCase() == 'open'
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 20,
                        color: Colors.orange[800],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.store.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Thông tin liên hệ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.store.address,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        widget.store.phoneNumber,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mô tả',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.store.description,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Danh sách món ăn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Products List
          if (isLoading)
            const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    ElevatedButton(
                      onPressed: _loadStoreProducts,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          else if (storeProducts.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Không có sản phẩm nào'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final product = storeProducts[index];
                      return GestureDetector(
                          onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailPage(
                              productId: product.id,
                            ),
                          ),
                        );
                      },
                          child:Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  image: product.image != null
                                      ? DecorationImage(
                                    image: NetworkImage(product.image!),
                                    fit: BoxFit.cover,
                                  )
                                      : null,
                                ),
                                child: product.image == null
                                    ? Center(
                                  child: Icon(
                                    Icons.fastfood,
                                    size: 40,
                                    color: Colors.orange[800],
                                  ),
                                )
                                    : null,
                              ),
                            ),
                            // Product Info
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${product.price.toStringAsFixed(0)}₫',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.orange[800],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        product.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                          ),
                      );
                    },
                    childCount: storeProducts.length,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}