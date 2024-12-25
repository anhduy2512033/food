class Store {
  String id;
  String name;
  String description;
  String phoneNumber;
  String address;
  String status;
  double rating;
  String? image; // Add optional image property

  Store({
    required this.id,
    required this.name,
    required this.description,
    required this.phoneNumber,
    required this.address,
    required this.status,
    required this.rating,
    this.image, // Add image to constructor
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'phoneNumber': phoneNumber,
      'address': address,
      'status': status,
      'rating': rating,
      'image': image, // Add image to map
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      phoneNumber: map['phoneNumber'] as String,
      address: map['address'] as String,
      status: map['status'] as String,
      rating: (map['rating'] is int)
          ? (map['rating'] as int).toDouble()
          : map['rating'] as double,
      image: map['image'] as String?, // Parse image from map
    );
  }
}