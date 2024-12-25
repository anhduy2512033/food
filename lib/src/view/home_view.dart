import 'package:flutter/material.dart';
import 'package:flutter_application_2/src/view/profile/profileScreen.dart';
import 'order/listOrder.dart';
import 'profile/accountTab.dart';
import 'favorite/favoriteTab.dart';
import 'Home/homeTab.dart';
import 'notification/notificationsTab.dart';

class FoodHomePage extends StatefulWidget {
  @override
  _FoodHomePageState createState() => _FoodHomePageState();
}

class _FoodHomePageState extends State<FoodHomePage> with SingleTickerProviderStateMixin {

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // 5 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: [
          HomeTab(),
          OrdersTab(),
          FavoritesTab(),
          NotificationsTab(),
          UserProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.red, // Màu nền của TabBar
        child: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.restaurant_outlined), text: "Trang chủ"),
            Tab(icon: Icon(Icons.list_alt_outlined), text: "Đơn hàng"),
            Tab(icon: Icon(Icons.favorite_outline), text: "Yêu thích"),
            Tab(icon: Icon(Icons.notifications_outlined), text: "Thông báo"),
            Tab(icon: Icon(Icons.person_outline), text: "Tài khoản"),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.red,
        ),
      ),
    );
  }
}