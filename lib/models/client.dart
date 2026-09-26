class Client {
  const Client({
    required this.id,
    required this.name,
    required this.email,
    required this.city,
    required this.joinedAt,
    this.deletedAt,
  });

  final int id;
  final String name;
  final String email;
  final String city;
  final DateTime joinedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Client copyWith({
    String? name,
    String? email,
    String? city,
    DateTime? joinedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      city: city ?? this.city,
      joinedAt: joinedAt ?? this.joinedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
