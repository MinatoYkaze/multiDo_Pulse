class MessageResponse {
  final String message;
  const MessageResponse({required this.message});
  factory MessageResponse.fromJson(Map<String, dynamic> j) =>
      MessageResponse(message: (j['message'] ?? j['detail'] ?? '').toString());
  Map<String, dynamic> toJson() => {'message': message};
}

/// Body for user creation / profile (GET /auth/me returns the same shape).
class UserPost {
  final String? id;
  final String email;
  final String? name;
  final String? picture;
  const UserPost({this.id, required this.email, this.name, this.picture});

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : email.split('@').first;

  factory UserPost.fromJson(Map<String, dynamic> j) => UserPost(
        id: j['id']?.toString(),
        email: (j['email'] ?? '') as String,
        name: (j['name'] ?? j['full_name']) as String?,
        picture: (j['picture'] ?? j['avatar_url']) as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'email': email,
        if (name != null) 'name': name,
        if (picture != null) 'picture': picture,
      };
}
