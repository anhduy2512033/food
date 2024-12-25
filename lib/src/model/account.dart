class Account {
  String? id;
  String email;
  String phone;
  String pass;  // Added password field
  int? createdAt;

  Account({
    this.id,
    required this.email,
    required this.phone,
    required this.pass,  // Added to constructor
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'pass': pass,  // Added to map
      'createdAt': createdAt,
    };
  }

  factory Account.fromMap(String id, Map<String, dynamic> map) {
    return Account(
      id: id,
      email: map['email'] as String,
      phone: map['phone'] as String,
      pass: map['pass'] as String,  // Added to factory constructor
      createdAt: map['createdAt'] as int?,
    );
  }
}