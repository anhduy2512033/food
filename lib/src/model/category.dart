class Category {
  String id;
  String name;
  String description;
  String? image; // Image can be nullable

  Category({
    required this.id,
    required this.name,
    required this.description,
    this.image,
  });

  // Method to convert Category object to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
    };
  }

  // Method to create a Category object from a map
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      image: map['image'] as String?, // Cast to String? for nullable image
    );
  }
}