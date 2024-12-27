import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart' as latlong2;
import '../../categoryScreen.dart';
import '../../model/category.dart';

import '../../model/food.dart';
import '../../model/ingredients_item.dart';
import '../../model/restaurant.dart';
import '../map/showlocation.dart';
import '../order/cartScreen.dart';
import '../productScreen.dart';
import '../storeScreen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Category> categories = [];
  List<Food> products = [];
  List<Restaurant> stores = [];
  bool isLoading = true;
  String? error;

  // Thêm các biến để quản lý tìm kiếm
  final TextEditingController _searchController = TextEditingController();
  List<Food> filteredProducts = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Thêm hàm tìm kiếm
  void _searchProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        isSearching = false;
        filteredProducts = [];
      } else {
        isSearching = true;
        final searchLower = query.toLowerCase();

        // Tìm kiếm trong danh sách sản phẩm
        List<Food> productResults = products.where((product) {
          final nameLower = product.name?.toLowerCase();
          final storeName = product.restaurant?.name?.toLowerCase();
          return nameLower!.contains(searchLower) ||
              storeName!.contains(searchLower);
        }).toList();

        // Tìm kiếm trong danh sách cửa hàng và lấy sản phẩm của cửa hàng đó
        List<Food> storeProducts = [];
        for (var store in stores) {
          if (store.name!.toLowerCase().contains(searchLower)) {
            storeProducts.addAll(
                products.where((product) => product.restaurant?.id == store.id));
          }
        }

        // Kết hợp kết quả và loại bỏ trùng lặp
        filteredProducts = {...productResults, ...storeProducts}.toList();

      }
    });
  }

  // Sửa lại phần search bar trong build method
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _searchProducts,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchProducts('');
                  },
                )
              : null,
          hintText: "Tìm kiếm món ăn yêu thích...",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
        ),
      ),
    );
  }

  // Sửa lại phần build chính để hiển thị kết quả tìm kiếm
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            // Search Bar
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _searchProducts,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    hintText: "Tìm kiếm món ăn...",
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey[500],
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _searchProducts('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Icon vị trí
          IconButton(
            icon: Icon(
              Icons.location_on_outlined,
              color: Colors.red[800],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationPicker(
                    onLocationSelected: (location) {
                      print(
                          'Vị trí đã chọn: ${location.latitude}, ${location.longitude}');
                    },
                  ),
                ),
              );
            },
          ),
          // Icon giỏ hàng
          IconButton(
            icon: Icon(
              Icons.shopping_cart_outlined,
              color: Colors.red[800],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSearching)
                _buildSearchResults()
              else ...[
                _buildCategories(),
                _buildStores(),
                _buildPopularProducts(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
        // Clear existing data
        stores.clear();
        categories.clear();
        products.clear();
      });

      // Load stores first
      final storesSnapshot = await _database.child('stores').get();
      final Map<String, Restaurant> storesMap = {};

      if (storesSnapshot.exists && storesSnapshot.value != null) {
        final storesData =
            Map<String, dynamic>.from(storesSnapshot.value as Map);
        await Future.forEach(storesData.entries,
            (MapEntry<String, dynamic> entry) async {
          try {
            if (entry.value is Map) {
              final storeData = Map<String, dynamic>.from(entry.value);
              // Ensure ID is set
              storeData['id'] = entry.key;

              // Print debug information
              print('Processing store: ${entry.key}');
              print('Store data: $storeData');

              final store = Restaurant.fromMap(storeData);
              stores.add(store);
              storesMap[entry.key] = store;

              print('Store processed successfully: ${store.name}');
            }
          } catch (e) {
            print('Error processing store ${entry.key}: $e');
          }
        });
      }

      // Load categories
      final categoriesSnapshot = await _database.child('categories').get();
      final Map<String, Category> categoriesMap = {};

      if (categoriesSnapshot.exists && categoriesSnapshot.value != null) {
        final categoriesData =
            Map<String, dynamic>.from(categoriesSnapshot.value as Map);
        categoriesData.forEach((key, value) {
          try {
            if (value is Map) {
              final categoryData = Map<String, dynamic>.from(value);
              categoryData['id'] = key;
              final category = Category.fromMap(categoryData);
              categories.add(category);
              categoriesMap[key] = category;
            }
          } catch (e) {
            print('Error processing category $key: $e');
          }
        });
      }

      // Load products
      final productsSnapshot = await _database.child('products').get();
      if (productsSnapshot.exists && productsSnapshot.value != null) {
        final productsData =
            Map<String, dynamic>.from(productsSnapshot.value as Map);
        await Future.forEach(productsData.entries,
            (MapEntry<String, dynamic> entry) async {
          try {
            if (entry.value is Map) {
              final productData = Map<String, dynamic>.from(entry.value);
              productData['id'] = entry.key;

              // Debug log
              print('Processing product: ${entry.key}');
              print('Product data: $productData');

              final storeId = productData['storeId']?.toString();
              final categoryId = productData['categoryId']?.toString();

              print('Store ID: $storeId');
              print('Category ID: $categoryId');

              if (storeId != null &&
                  categoryId != null &&
                  storesMap.containsKey(storeId) &&
                  categoriesMap.containsKey(categoryId)) {
                final product = Food(
                  id: int.tryParse(entry.key) ?? 0,
                  name: productData['name']?.toString() ?? '',
                  price: (productData['price'] as num?)?.toInt(),  // Đổi sang int cho price
                  description: productData['description']?.toString() ?? '',
                  foodCategory: productData['categoryId'] != null
                      ? categoriesMap[productData['categoryId']]
                      : null,  // Lấy category từ categoriesMap
                  images: productData['images'] != null
                      ? List<String>.from(productData['images'])  // Chuyển danh sách hình ảnh
                      : [],
                  available: productData['status'] == 'available',  // Kiểm tra trạng thái món ăn
                  restaurant: storesMap[storeId],  // Lấy nhà hàng từ storesMap
                  isVegetarian: productData['isVegetarian'] ?? false,  // Nếu không có thì mặc định là false
                  isSeasonal: productData['isSeasonal'] ?? false,  // Nếu không có thì mặc định là false
                  ingredients: productData['ingredients'] != null
                      ? List<IngredientsItem>.from(productData['ingredients'].map((item) =>
                      IngredientsItem.fromMap(item))) // Lấy danh sách nguyên liệu
                      : [],
                  creationDate: productData['creationDate'] != null
                      ? DateTime.parse(productData['creationDate'])  // Chuyển creationDate từ chuỗi
                      : null,
                );

                products.add(product);
                print('Product processed successfully: ${product.name}');
              } else {
                print(
                    'Skipping product ${entry.key} - missing store or category');
                print('Available store IDs: ${storesMap.keys.toList()}');
                print('Available category IDs: ${categoriesMap.keys.toList()}');
              }
            }
          } catch (e) {
            print('Error processing product ${entry.key}: $e');
            print('Stack trace: ${StackTrace.current}');
          }
        });

      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error loading data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          error = 'Có lỗi xảy ra khi tải dữ liệu: $e';
          isLoading = false;
        });
      }
    }
  }

  void _showLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPicker(
        onLocationSelected: (latlong2.LatLng location) {
          print('Vị trí đã chọn: ${location.latitude}, ${location.longitude}');
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Food',
              style: TextStyle(
                color: Colors.red[800],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const TextSpan(
              text: 'App',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.location_on_outlined),
              color: Colors.black87,
              onPressed: () => _showLocationPicker(context),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            color: Colors.black87,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(Category category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryProductScreen(
              category: category,
              allProducts: products, // Truyền toàn bộ danh sách sản phẩm
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(15),
                // Không có hình ảnh trong Category, nên bỏ phần image
              ),
              child: Icon(
                Icons.category,
                color: Colors.red[800],
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name ?? '', // Kiểm tra null trước khi sử dụng
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Add this method to the _HomeTabState class

  Widget _buildStoreItem(Restaurant store) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoreScreen(
              store: store,
              userId: 'current-user-id', // Replace with actual user ID
            ),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                image: store.images != null && store.images!.isNotEmpty
                    ? DecorationImage(
                  image: NetworkImage(store.images![0]),
                  fit: BoxFit.cover,
                )
                    : null,
                color: Colors.grey[100],
              ),
              child: store.images == null || store.images!.isEmpty
                  ? Center(
                child: Icon(
                  Icons.store,
                  size: 40,
                  color: Colors.red[800],
                ),
              )
                  : null,
            ),
            // Store Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name ?? '', // Ensure `store.name` is not null
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.address?.toString() ?? '', // Displaying address if exists
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.red[800],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.open != null && store.open! ? 'Open' : 'Closed', // Check open status
                        style: TextStyle(
                          color: store.open != null && store.open! ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: store.open != null && store.open! ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          store.open != null && store.open! ? 'Open' : 'Closed',
                          style: TextStyle(
                            color: store.open != null && store.open! ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
  }


// Update the build method in _HomeTabState to include the stores section
// Add this section between Categories and Popular Products:
  Widget _buildProductItem(Food product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: product.id!.toString()),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  image: product.images != null && product.images!.isNotEmpty
                      ? DecorationImage(
                    image: NetworkImage(product.images![0]),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: product.images == null || product.images!.isEmpty
                    ? Icon(
                  Icons.food_bank,
                  size: 40,
                  color: Colors.red[800],
                )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name ?? '', // Ensure product.name is not null
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description ?? '', // Ensure description is not null
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cửa hàng: ${product.restaurant?.name ?? 'Không xác định'}', // Ensure restaurant name is not null
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.red[800],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.available != null && product.available!
                              ? 'Còn hàng'
                              : 'Hết hàng',
                          style: TextStyle(
                            color: product.available != null && product.available!
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${product.price?.toStringAsFixed(0) ?? '0'}₫', // Ensure price is not null
                          style: TextStyle(
                            color: Colors.red[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      ),
    );
  }
  Widget _buildCategories() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh Mục',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryItem(categories[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStores() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cửa Hàng Nổi Bật',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: stores.length,
              itemBuilder: (context, index) {
                return _buildStoreItem(stores[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularProducts() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Món Ăn Phổ Biến',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductItem(products[index]);
            },
          ),
        ],
      ),
    );
  }

  // Thêm widget hiển thị kết quả tìm kiếm
  Widget _buildSearchResults() {
    if (filteredProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'Không tìm thấy kết quả',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tìm thấy ${filteredProducts.length} kết quả',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return _buildProductItem(product);
            },
          ),
        ],
      ),
    );
  }
}
