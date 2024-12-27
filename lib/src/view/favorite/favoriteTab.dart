import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../model/restaurant.dart';
import '../storeScreen.dart';


class FavoritesTab extends StatefulWidget {
  @override
  _FavoritesTabState createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> with SingleTickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  List<Restaurant> favoriteStores = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
    _loadFavoriteStores();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteStores() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          error = 'Vui lòng đăng nhập để xem danh sách yêu thích';
          isLoading = false;
        });
        return;
      }

      // Get favorites for current user
      final favoritesSnapshot = await _database
          .child('favorites')
          .orderByChild('userId')
          .equalTo(currentUser.uid)
          .get();

      if (!favoritesSnapshot.exists || favoritesSnapshot.value == null) {
        setState(() {
          favoriteStores = [];
          isLoading = false;
        });
        return;
      }

      // Get all stores data
      final storesSnapshot = await _database.child('stores').get();
      if (!storesSnapshot.exists || storesSnapshot.value == null) {
        setState(() {
          error = 'Không thể tải thông tin cửa hàng';
          isLoading = false;
        });
        return;
      }

      final storesData = Map<String, dynamic>.from(storesSnapshot.value as Map);
      final favoritesData = Map<String, dynamic>.from(favoritesSnapshot.value as Map);

      // Create list of favorite stores
      final List<Restaurant> stores = [];
      for (var favorite in favoritesData.values) {
        final String storeId = favorite['storeId'] as String;
        if (storesData.containsKey(storeId)) {
          final storeData = Map<String, dynamic>.from(storesData[storeId] as Map);
          storeData['id'] = storeId;
          stores.add(Restaurant.fromMap(storeData));
        }
      }

      setState(() {
        favoriteStores = stores;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Có lỗi xảy ra: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Cửa Hàng Yêu Thích',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red[800],
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: error != null
          ? _buildErrorState()
          : favoriteStores.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
    );
  }

  Widget _buildFavoritesList() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 20,
            ),
            itemCount: favoriteStores.length,
            itemBuilder: (context, index) {
              final store = favoriteStores[index];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final delay = index * 0.2;
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Interval(
                        delay.clamp(0, 1),
                        (delay + 0.4).clamp(0, 1),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  );

                  return SlideTransition(
                    position: slideAnimation,
                    child: _buildStoreCard(store),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStoreCard(Restaurant store) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToStoreDetail(store),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  _buildStoreImage(store),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildFavoriteButton(),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        Icons.favorite_rounded,
        color: Colors.red[400],
        size: 18,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có cửa hàng yêu thích nào',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thêm các cửa hàng bạn yêu thích',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 60,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadFavoriteStores,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreImage(Restaurant store) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: AspectRatio(
        aspectRatio: 1.2,
        child: store.images != null && store.images!.isNotEmpty
            ? Image.network(
          store.images!.first,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Icon(
        Icons.store_rounded,
        size: 40,
        color: Colors.red[800],
      ),
    );
  }

  void _navigateToStoreDetail(Restaurant store) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StoreScreen(
          store: store,
          userId: FirebaseAuth.instance.currentUser!.uid,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}