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
import '../../model/product.dart';
import '../../model/store.dart';
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
  List<Product> products = [];
  List<Store> stores = [];
  bool isLoading = true;
  String? error;

  // Thêm các biến để quản lý tìm kiếm
  final TextEditingController _searchController = TextEditingController();
  List<Product> filteredProducts = [];
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
        List<Product> productResults = products.where((product) {
          final nameLower = product.name.toLowerCase();
          final storeName = product.store.name.toLowerCase();
          return nameLower.contains(searchLower) ||
              storeName.contains(searchLower);
        }).toList();

        // Tìm kiếm trong danh sách cửa hàng và lấy sản phẩm của cửa hàng đó
        List<Product> storeProducts = [];
        for (var store in stores) {
          if (store.name.toLowerCase().contains(searchLower)) {
            storeProducts.addAll(
                products.where((product) => product.store.id == store.id));
          }
        }

        // Kết hợp kết quả và loại bỏ trùng lặp
        filteredProducts = {...productResults, ...storeProducts}.toList();

        // Sắp xếp theo rating
        filteredProducts.sort((a, b) => b.rating.compareTo(a.rating));
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
      final Map<String, Store> storesMap = {};

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

              final store = Store.fromMap(storeData);
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
                final product = Product(
                  id: entry.key,
                  name: productData['name']?.toString() ?? '',
                  price: (productData['price'] as num?)?.toDouble() ?? 0,
                  description: productData['description']?.toString() ?? '',
                  status: productData['status']?.toString() ?? '',
                  rating: (productData['rating'] as num?)?.toDouble() ?? 0,
                  image: productData['image']?.toString() ?? '',
                  thumbnail: productData['thumbnail']?.toString() ?? '',
                  store: storesMap[storeId]!,
                  category: categoriesMap[categoryId]!,
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

        // Sort products by rating
        products.sort((a, b) => b.rating.compareTo(a.rating));
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
                image: category.image != null
                    ? DecorationImage(
                        image: NetworkImage(category.image!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: category.image == null
                  ? Icon(
                      Icons.category,
                      color: Colors.red[800],
                      size: 30,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
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

  Widget _buildStoreItem(Store store) {
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                image: store.image != null
                    ? DecorationImage(
                        image: NetworkImage(store.image!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[100],
              ),
              child: store.image == null
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
                    store.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.address,
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
                        store.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.red[800],
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
                          color: store.status.toLowerCase() == 'open'
                              ? Colors.green[50]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          store.status,
                          style: TextStyle(
                            color: store.status.toLowerCase() == 'open'
                                ? Colors.green
                                : Colors.red,
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
  Widget _buildProductItem(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: product.id),
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  image: product.image != null
                      ? DecorationImage(
                          image: NetworkImage(product.image!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.image == null
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
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cửa hàng: ${product.store.name}',
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
                          product.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.red[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${product.price.toStringAsFixed(0)}₫',
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
