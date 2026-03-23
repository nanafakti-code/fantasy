class Usuario {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  const Usuario({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };

  String get initials {
    final parts = username.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.substring(0, 2).toUpperCase();
  }
}
