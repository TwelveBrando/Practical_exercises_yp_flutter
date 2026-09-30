import 'agency_record.dart';
import 'json_readers.dart';

class AgencyService implements AgencyRecord {
  const AgencyService({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  final int id;
  @override
  final String name;
  final String description;
  final String category;
  final int price;
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
    'category': category,
    'price': price,
    'createdAt': createdAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory AgencyService.fromJson(Map<String, dynamic> json) => AgencyService(
    id: readInt(json['id']),
    name: readString(json['name']),
    description: readString(json['description']),
    category: readString(json['category']),
    price: readInt(json['price']),
    createdAt: readDate(json['createdAt']),
    deletedAt: readOptionalDate(json['deletedAt']),
  );
}
