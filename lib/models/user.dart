class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}
