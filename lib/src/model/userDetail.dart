class userDetail {
  String id;
  String? image;
  String? gioitinh;
  String? date; // Make date nullable
  String? diachi;
  int? createdAt;

  userDetail({
    required this.id,
    this.image = 'assets/img/defaultAvatar.png',
    this.gioitinh, // Remove required for gioitinh
    this.date, // No required for date, defaults to null
    this.diachi, // Remove required for diachi
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Include id in the map
      'image': image,
      'gioitinh': gioitinh,
      'date': date, // date can be null
      'diachi': diachi,
      'createdAt': createdAt,
    };
  }

  factory userDetail.fromMap(String id, Map<String, dynamic> map) {
    return userDetail(
      id: id,
      image: map['image'] as String?,
      gioitinh: map['gioitinh'] as String?,
      date: map['date'] as String?, // Cast to String?
      diachi: map['diachi'] as String?,
      createdAt: map['createdAt'] as int?,
    );
  }
}