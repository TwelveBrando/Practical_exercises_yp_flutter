import 'agency_record.dart';
import 'client_card.dart';
import 'json_readers.dart';

class Client implements AgencyRecord {
  const Client({
    required this.id,
    required this.name,
    required this.email,
    required this.city,
    required this.joinedAt,
    this.deletedAt,
    this.card,
  });

  @override
  final int id;
  @override
  final String name;
  final String email;
  final String city;
  final DateTime joinedAt;
  @override
  final DateTime? deletedAt;
  final ClientCard? card;
  @override
  DateTime get date => joinedAt;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'city': city,
    'joinedAt': joinedAt.toIso8601String(),
    'card': card?.toJson(),
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: readInt(json['id']),
    name: readString(json['name']),
    email: readString(json['email']),
    city: readString(json['city']),
    joinedAt: readDate(json['joinedAt']),
    card: json['card'] is Map
        ? ClientCard.fromJson(readMap(json['card']))
        : null,
    deletedAt: readOptionalDate(json['deletedAt']),
  );

  @override
  bool get isDeleted => deletedAt != null;

  Client copyWith({
    String? name,
    String? email,
    String? city,
    DateTime? joinedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    ClientCard? card,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      city: city ?? this.city,
      joinedAt: joinedAt ?? this.joinedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      card: card ?? this.card,
    );
  }
}
