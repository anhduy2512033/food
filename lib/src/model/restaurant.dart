import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_application_2/src/model/restaurant.dart';
import 'contact_information.dart';
import 'food.dart';
import 'order.dart';
import 'user.dart';
import 'address.dart';
import 'order_item.dart';


class Restaurant {
  int? id;
  User? owner;
  String? name;
  String? description;
  String? cuisineType;
  Address? address;
  ContactInformation? contactInformation;
  String? openingHours;
  List<Order>? orders;
  List<String>? images;
  DateTime? registrationDate;
  bool? open;
  List<Food>? foods;

  Restaurant({
    this.id,
    this.owner,
    this.name,
    this.description,
    this.cuisineType,
    this.address,
    this.contactInformation,
    this.openingHours,
    this.orders,
    this.images,
    this.registrationDate,
    this.open,
    this.foods,
  });

  // Tạo đối tượng Restaurant từ Map
  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'],
      owner: map['owner'] != null ? User.fromMap(map['owner']) : null,
      name: map['name'],
      description: map['description'],
      cuisineType: map['cuisineType'],
      address: map['address'] != null ? Address.fromMap(map['address']) : null,
      contactInformation: map['contactInformation'] != null
          ? ContactInformation.fromMap(map['contactInformation'])
          : null,
      openingHours: map['openingHours'],
      orders: map['orders'] != null
          ? List<Order>.from(map['orders'].map((order) => Order.fromMap(order)))
          : [],
      images: map['images'] != null ? List<String>.from(map['images']) : [],
      registrationDate: map['registrationDate'] != null
          ? DateTime.parse(map['registrationDate'])
          : null,
      open: map['open'],
      foods: map['foods'] != null
          ? List<Food>.from(map['foods'].map((food) => Food.fromMap(food)))
          : [],
    );
  }

  // Chuyển đối tượng Restaurant thành Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner': owner?.toMap(),
      'name': name,
      'description': description,
      'cuisineType': cuisineType,
      'address': address?.toMap(),
      'contactInformation': contactInformation?.toMap(),
      'openingHours': openingHours,
      'orders': orders?.map((order) => order.toMap()).toList(),
      'images': images,
      'registrationDate': registrationDate?.toIso8601String(),
      'open': open,
      'foods': foods?.map((food) => food.toMap()).toList(),
    };
  }
}
