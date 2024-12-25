class Coupon {
  int? id;
  String? name;
  int? quantity; // Thay Long bằng int
  int? value;    // Thay Long bằng int (giá trị chiết khấu)
  DateTime? createdAt;
  DateTime? expiresAt;

  Coupon({
    this.id,
    this.name,
    this.quantity,
    this.value,
    this.createdAt,
    this.expiresAt,
  });

  // Tạo đối tượng Coupon từ Map
  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'],
      value: map['value'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null, // Chuyển đổi chuỗi thành DateTime
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'])
          : null, // Chuyển đổi chuỗi thành DateTime
    );
  }

  // Chuyển đối tượng Coupon thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'value': value,
      'createdAt': createdAt?.toIso8601String(), // Chuyển DateTime thành chuỗi
      'expiresAt': expiresAt?.toIso8601String(), // Chuyển DateTime thành chuỗi
    };
  }
}
