import 'json_readers.dart';

class ClientCard {
  const ClientCard({
    required this.number,
    required this.issuedAt,
    this.points = 0,
  });
  final String number;
  final DateTime issuedAt;
  final int points;
  Map<String, dynamic> toJson() => {
    'number': number,
    'issuedAt': issuedAt.toIso8601String(),
    'points': points,
  };
  factory ClientCard.fromJson(Map<String, dynamic> json) => ClientCard(
    number: readString(json['number']),
    issuedAt: readDate(json['issuedAt']),
    points: readInt(json['points']),
  );
}
