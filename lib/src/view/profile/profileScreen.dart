import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../account/Login_view.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../model/feedback.dart' as FeedbackModel;

class UserProfileScreen extends StatefulWidget {
  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirAuth _auth = FirAuth();
  Map<String, dynamic>? _userDetails;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _updateAvatar() async {
    try {
      // Hiển thị bottom sheet cho phép user chọn nguồn ảnh
      await showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Chọn từ thư viện'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Chụp ảnh mới'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _showErrorMessage('Không thể mở trình chọn ảnh');
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      setState(() => _isUploadingImage = true);

      // Chọn ảnh từ nguồn đã chọn
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800, // Giảm kích thước ảnh
        maxHeight: 800,
        imageQuality: 70, // Giảm chất lượng để giảm dung lượng
      );

      if (pickedFile == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

      // Đọc file ảnh và chuyển đổi thành base64
      final File imageFile = File(pickedFile.path);
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Kiểm tra kích thước base64 string
      final int sizeInBytes = base64Image.length;
      final double sizeInMB = sizeInBytes / (1024 * 1024);

      // Giới hạn kích thước là 1MB
      if (sizeInMB > 1) {
        setState(() => _isUploadingImage = false);
        _showErrorMessage('Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn');
        return;
      }

      // Lấy reference của user hiện tại
      final User? currentUser = _auth.getCurrentUser();
      if (currentUser == null) throw Exception("Người dùng chưa đăng nhập");

      // Cập nhật base64 string vào userDetail trong Firestore
      await _auth.updateUserDetail(
          currentUser.uid, {'image': 'data:image/jpeg;base64,$base64Image'});

      // Reload dữ liệu user
      await _loadUserData();

      setState(() => _isUploadingImage = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật ảnh đại diện thành công')),
      );
    } catch (error) {
      setState(() => _isUploadingImage = false);
      _showErrorMessage('Lỗi khi cập nhật ảnh: ${error.toString()}');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final jwtToken = await _getSavedJwtToken();

      if (jwtToken == null) {
        throw Exception("Không tìm thấy JWT token");
      }

      // Gửi yêu cầu GET đến backend
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/api/users/profile'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Dữ liệu trả về từ API: $data");
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      } else {
        // Xử lý lỗi từ server
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? "Không thể tải thông tin người dùng");
      }
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải thông tin: ${error.toString()}')),
      );
    }
  }

  Future<String?> _getSavedJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwtToken');
  }


  Future<void> _updateUserDetail(String field, dynamic value) async {
    try {
      final User? currentUser = _auth.getCurrentUser();
      if (currentUser == null) return;

      // Update specific field
      await _auth.updateUserDetail(currentUser.uid, {field: value});

      // Reload data to show updates
      await _loadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật thành công')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật: ${error.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.red,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Avatar và thông tin cơ bản
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: _buildAvatar(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _updateAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 20,
                              color: Colors.red[800],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tên người dùng
                  Text(
                    _userData?['fullName'] ?? 'Chưa cập nhật tên',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Email
                  Text(
                    _userData?['email'] ?? 'Chưa có email',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Profile Options
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildOptionItem(
                    'Thông tin cá nhân',
                    Icons.person_outline_rounded,
                    _showEditProfileDialog,
                  ),
                  _buildOptionItem(
                    'Đổi mật khẩu',
                    Icons.lock_outline_rounded,
                    _showChangePasswordDialog,
                  ),
                  _buildOptionItem(
                    'Danh sách đánh giá',
                    Icons.star_outline_rounded,
                    _showReviewsList,
                  ),
                  _buildOptionItem(
                    'Đăng xuất',
                    Icons.logout_rounded,
                        () async {
                      final confirmed = await _showLogoutConfirmDialog();
                      if (confirmed == true) {
                        await _handleLogout();
                      }
                    },
                    textColor: Colors.red[700],
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    try {
      if (_userDetails != null &&
          _userDetails!['image'] != null &&
          _userDetails!['image'].toString().startsWith('data:image')) {
        final imageData = _userDetails!['image'].toString().split(',');
        if (imageData.length > 1) {
          return Image.memory(
            base64Decode(imageData[1]),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
          );
        }
      }
      return _buildDefaultAvatar();
    } catch (e) {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: Icon(
        Icons.person_rounded,
        size: 60,
        color: Colors.grey[400],
      ),
    );
  }

  Future<bool?> _showLogoutConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Đăng xuất',
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await _auth.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => Login()),
          (route) => false,
    );
  }

  Widget _buildOptionItem(
      String title,
      IconData icon,
      VoidCallback onTap, {
        Color? textColor,
        bool showDivider = true,
      }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: textColor ?? Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor ?? Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final TextEditingController currentPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassController,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPassController,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPassController,
                  decoration: const InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            if (isLoading)
              const CircularProgressIndicator()
            else
              TextButton(
                onPressed: () async {
                  if (newPassController.text != confirmPassController.text) {
                    _showErrorMessage('Mật khẩu mới không khớp');
                    return;
                  }

                  setState(() => isLoading = true);

                  try {
                    final user = _auth.getCurrentUser();
                    if (user != null) {
                      // Xác thực lại người dùng với mật khẩu hiện tại
                      final credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: currentPassController.text,
                      );
                      await user.reauthenticateWithCredential(credential);

                      // Đổi mật khẩu
                      await user.updatePassword(newPassController.text);

                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                            content: Text('Đổi mật khẩu thành công')),
                      );
                    }
                  } catch (e) {
                    _showErrorMessage('Mật khẩu hiện tại không đúng');
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
                child: const Text('Xác nhận'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final TextEditingController nameController =
    TextEditingController(text: _userData?['fullName']);
    final TextEditingController phoneController =
    TextEditingController(text: _userData?['phone']);
    final TextEditingController addressController =
    TextEditingController(text: _userDetails?['diachi']);
    String? selectedGender = _userDetails?['gioitinh'];
    String? selectedDate = _userDetails?['date'];
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chỉnh sửa thông tin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Họ tên
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Số điện thoại
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Giới tính
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Giới tính',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                    DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                    DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedGender = value);
                  },
                ),
                const SizedBox(height: 16),

                // Ngày sinh
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate != null
                          ? DateTime.parse(selectedDate!)
                          : DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked.toIso8601String().split('T')[0];
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày sinh',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      selectedDate ?? 'Chọn ngày sinh',
                      style: TextStyle(
                        color:
                        selectedDate != null ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Địa chỉ
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            if (isLoading)
              const CircularProgressIndicator()
            else
              TextButton(
                onPressed: () async {
                  setState(() => isLoading = true);
                  try {
                    final User? currentUser = _auth.getCurrentUser();
                    if (currentUser != null) {
                      // Cập nhật thông tin user
                      await FirebaseDatabase.instance
                          .ref()
                          .child('users')
                          .child(currentUser.uid)
                          .update({
                        'fullName': nameController.text,
                        'phone': phoneController.text,
                      });

                      // Cập nhật thông tin chi tiết
                      await _auth.updateUserDetail(currentUser.uid, {
                        'gioitinh': selectedGender,
                        'date': selectedDate,
                        'diachi': addressController.text,
                      });

                      await _loadUserData();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                            content: Text('Cập nhật thông tin thành công')),
                      );
                    }
                  } catch (e) {
                    _showErrorMessage('Lỗi khi cập nhật thông tin');
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
                child: const Text('Lưu'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReviewsList() async {
    try {
      final User? currentUser = _auth.getCurrentUser();
      if (currentUser == null) return;

      // Lấy danh sách đánh giá từ Firebase
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('feedbacks')
          .orderByChild('userId')
          .equalTo(currentUser.uid)
          .get();

      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có đánh giá nào')),
        );
        return;
      }

      final feedbacksMap = Map<String, dynamic>.from(snapshot.value as Map);
      List<FeedbackModel.Feedback> feedbacks = [];

      for (var entry in feedbacksMap.entries) {
        final feedbackData = Map<String, dynamic>.from(entry.value);
        feedbackData['id'] = entry.key;

        // Lấy thông tin người dùng
        Map<String, dynamic> userData = {
          'id': feedbackData['userId'],
          'fullName': 'Người dùng ẩn danh',
          'email': '',
          'phone': '',
        };

        if (feedbackData['userId'] != null) {
          final userSnapshot = await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(feedbackData['userId'])
              .get();

          if (userSnapshot.exists) {
            userData = Map<String, dynamic>.from(userSnapshot.value as Map);
            userData['id'] = feedbackData['userId'];
          }
        }

        // Lấy thông tin sản phẩm
        final productSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('products')
            .child(feedbackData['productId'])
            .get();

        if (productSnapshot.exists) {
          final productData =
          Map<String, dynamic>.from(productSnapshot.value as Map);
          productData['id'] = feedbackData['productId'];

          // Tạo đối tượng Feedback
          feedbacks.add(FeedbackModel.Feedback.fromMap(
              feedbackData, userData, productData));
        }
      }

      // Hiển thị danh sách đánh giá
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Danh sách đánh giá'),
          content: SizedBox(
            height: 400,
            width: 300,
            child: ListView.builder(
              itemCount: feedbacks.length,
              itemBuilder: (context, index) {
                final feedback = feedbacks[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback.user.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: List.generate(5, (starIndex) {
                            return Icon(
                              starIndex < feedback.rating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                        const SizedBox(height: 4),
                        Text(feedback.content),
                        if (feedback.image != null) ...[
                          const SizedBox(height: 8),
                          Image.memory(
                            base64Decode(feedback.image!.split(',').last),
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                feedback.createdAt),
                          ),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải danh sách đánh giá: ${error.toString()}'),
        ),
      );
    }
  }
}