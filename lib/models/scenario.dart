import 'agency_record.dart';
import 'json_readers.dart';

class Scenario implements AgencyRecord {
  const Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.serviceId,
    required this.durationMinutes,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  final int id;
  @override
  final String name;
  final String description;
  final int serviceId;
  final int durationMinutes;
  final DateTime createdAt;
  @override
  final DateTime? deletedAt;
  @override
  DateTime get date => createdAt;
  @override
  bool get isDeleted => deletedAt != null;
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'serviceId': serviceId,
    'durationMinutes': durationMinutes,
    'createdAt': createdAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Scenario.fromJson(Map<String, dynamic> json) => Scenario(
    id: readInt(json['id']),
    name: readString(json['name']),
    description: readString(json['description']),
    serviceId: readInt(json['serviceId'] ?? readMap(json['service'])['id']),
    durationMinutes: readInt(json['durationMinutes'], 30),
    createdAt: readDate(json['createdAt']),
    deletedAt: readOptionalDate(json['deletedAt']),
  );
}
