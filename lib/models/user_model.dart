import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String email;
  final DateTime accountCreationDate;
  final DateTime? lastLogin;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.accountCreationDate,
    this.lastLogin,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      userId: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      accountCreationDate: map['accountCreationDate'] is Timestamp
          ? (map['accountCreationDate'] as Timestamp).toDate()
          : DateTime.now(),
      lastLogin: map['lastLogin'] is Timestamp
          ? (map['lastLogin'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'accountCreationDate': accountCreationDate,
        'lastLogin': lastLogin,
      };
}
