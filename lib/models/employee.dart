import 'agency_record.dart';
import 'json_readers.dart';

class Employee implements AgencyRecord {
  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.specialty,
    required this.hiredAt,
    this.experienceYears = 0,
    this.deletedAt,
  });
  @override
  final int id;
  @override
  final String name;
  final String email;
  final String phone;
  final String specialty;
  final DateTime hiredAt;
  final int experienceYears;
  @override
  final DateTime? deletedAt;
  @override
  DateTime get date => hiredAt;
  @override
  bool get isDeleted => deletedAt != null;
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'specialty': specialty,
    'hiredAt': hiredAt.toIso8601String(),
    'experienceYears': experienceYears,
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: readInt(json['id']),
    name: readString(json['name']),
    email: readString(json['email']),
    phone: readString(json['phone']),
    specialty: readString(json['specialty']),
    hiredAt: readDate(json['hiredAt']),
    experienceYears: readInt(json['experienceYears']),
    deletedAt: readOptionalDate(json['deletedAt']),
  );
}
