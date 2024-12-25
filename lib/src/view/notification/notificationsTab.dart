import 'package:flutter/material.dart';
import 'discount_view.dart';
import 'news_view.dart';

class NotificationsTab extends StatefulWidget {
  @override
  _NotificationsTab createState() => _NotificationsTab();
}

class _NotificationsTab extends State<NotificationsTab> {
  final List<Map<String, dynamic>> items = [
    {
      'name': 'Khuyến mại',
      'icon': Icons.discount_outlined,
      'action':(context) { // Thêm context vào hàm action
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DiscountView()),
        );
      },
    },
    {
      'name': 'Tin tức',
      'icon': Icons.notifications_active_outlined,
      'action': (context) { // Thêm context vào hàm action
    Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => Newsview()),
    );
    },
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Thông Báo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red[800],
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phần menu thông báo
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item['icon'],
                        color: Colors.red[800],
                      ),
                    ),
                    title: Text(
                      item['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                    onTap: () => item['action']?.call(context),
                  );
                },
              ),
            ),

            // Phần cập nhật quan trọng
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                "Cập Nhật Quan Trọng",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),

            // Phần hiển thị trạng thái
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/img/iconhoadon.png',
                    width: 180,
                    height: 180,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Chưa Có Thông Tin Cập Nhật Mới",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Bạn sẽ nhận được thông báo khi có cập nhật mới",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
