import 'package:flutter/material.dart';

import 'model/category.dart';
import 'model/product.dart';
import 'view/productScreen.dart';


class CategoryProductScreen extends StatefulWidget {
  final Category category;
  final List<Product> allProducts;

  const CategoryProductScreen({
    Key? key,
    required this.category,
    required this.allProducts
  }) : super(key: key);

  @override
  _CategoryProductScreenState createState() => _CategoryProductScreenState();
}

class _CategoryProductScreenState extends State<CategoryProductScreen> {
  late List<Product> filteredProducts;
  String _searchQuery = '';
  String _selectedSort = 'default'; // default, price_asc, price_desc, rating

  @override
  void initState() {
    super.initState();
    _filterAndSortProducts();
  }

  void _filterAndSortProducts() {
    // Lọc sản phẩm theo danh mục
    filteredProducts = widget.allProducts
        .where((product) => 
            product.category.id == widget.category.id &&
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    // Sắp xếp sản phẩm
    switch (_selectedSort) {
      case 'price_asc':
        filteredProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        filteredProducts.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        filteredProducts.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        // Giữ nguyên thứ tự mặc định
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _buildProductList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.category.name,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.info_outline, color: Colors.orange[800]),
          onPressed: () => _showCategoryInfo(),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Thanh tìm kiếm
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filterAndSortProducts();
              });
            },
            decoration: InputDecoration(
              hintText: 'Tìm kiếm trong ${widget.category.name}',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Thanh lọc và sắp xếp
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Mặc định', 'default'),
                _buildFilterChip('Giá tăng dần ↑', 'price_asc'),
                _buildFilterChip('Giá giảm dần ↓', 'price_desc'),
                _buildFilterChip('Đánh giá cao', 'rating'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedSort == value,
        onSelected: (selected) {
          setState(() {
            _selectedSort = value;
            _filterAndSortProducts();
          });
        },
        selectedColor: Colors.orange[800],
        labelStyle: TextStyle(
          color: _selectedSort == value ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_food,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy sản phẩm nào',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductItem(filteredProducts[index]);
      },
    );
  }

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
          borderRadius: BorderRadius.circular(15),
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
              // Hình ảnh sản phẩm
              Hero(
                tag: 'product_${product.id}',
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: product.image != null
                        ? DecorationImage(
                            image: NetworkImage(product.image!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product.image == null
                      ? Icon(Icons.fastfood, color: Colors.orange[800], size: 40)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Thông tin sản phẩm
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.store.name,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.orange[800]),
                        const SizedBox(width: 4),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${product.price.toStringAsFixed(0)}₫',
                          style: TextStyle(
                            color: Colors.orange[800],
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

  void _showCategoryInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.category.description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${filteredProducts.length} sản phẩm',
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}