class Address {
  int? id;

  Address({this.id});

  // Tạo đối tượng từ Map (dùng để chuyển đổi dữ liệu JSON thành đối tượng Address)
  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'],
    );
  }

  // Chuyển đối tượng thành Map (dùng để chuyển đối tượng Address thành dữ liệu JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}
