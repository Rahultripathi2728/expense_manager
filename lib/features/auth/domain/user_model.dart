import 'package:appwrite/models.dart' as models;

class UserModel {
  final String id;
  final String name;
  final String email;
  final bool emailVerification;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerification,
  });

  factory UserModel.fromAppwrite(models.User user) {
    return UserModel(
      id: user.$id,
      name: user.name,
      email: user.email,
      emailVerification: user.emailVerification,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      emailVerification: json['emailVerification'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'emailVerification': emailVerification,
    };
  }
}
