class ContactInformation {
  String? email;
  String? mobile;
  String? twitter;
  String? instagram;

  ContactInformation({
    this.email,
    this.mobile,
    this.twitter,
    this.instagram,
  });

  // Tạo đối tượng ContactInformation từ Map
  factory ContactInformation.fromMap(Map<String, dynamic> map) {
    return ContactInformation(
      email: map['email'],
      mobile: map['mobile'],
      twitter: map['twitter'],
      instagram: map['instagram'],
    );
  }

  // Chuyển đối tượng ContactInformation thành Map
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'mobile': mobile,
      'twitter': twitter,
      'instagram': instagram,
    };
  }
}