class User {
  String id;
  String fullName;
  String email;
  String phone;
  int? createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Đảm bảo thêm id vào Map
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'createdAt': createdAt,
    };
  }

  // Sửa phương thức fromMap để chỉ nhận một tham số Map<String, dynamic>
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,  // Lấy id từ Map
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      createdAt: map['createdAt'] as int?,
    );
  }
}
