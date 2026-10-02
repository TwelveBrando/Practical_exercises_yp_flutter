import 'agency_record.dart';
import 'json_readers.dart';

enum RequestStatus { newRequest, inProgress, ready, closed }

enum RequestType { lateForWork, missedMeeting, missedDeadline, awkwardEvent }

const requestStatusLabels = <RequestStatus, String>{
  RequestStatus.newRequest: 'Новая',
  RequestStatus.inProgress: 'В работе',
  RequestStatus.ready: 'Готова',
  RequestStatus.closed: 'Закрыта',
};
const requestTypeLabels = <RequestType, String>{
  RequestType.lateForWork: 'Опоздание',
  RequestType.missedMeeting: 'Пропущенная встреча',
  RequestType.missedDeadline: 'Сорванный срок',
  RequestType.awkwardEvent: 'Неловкое событие',
};

class AlibiRequest implements AgencyRecord {
  const AlibiRequest({
    required this.id,
    required this.clientId,
    required this.title,
    required this.type,
    required this.status,
    required this.eventDate,
    required this.createdAt,
    required this.urgency,
    this.deletedAt,
    this.code = '',
    this.serviceId = 1,
    this.employeeIds = const [],
    this.scenarioIds = const [],
  });

  @override
  final int id;
  final int clientId;
  final String title;
  final RequestType type;
  final RequestStatus status;
  final DateTime eventDate;
  final DateTime createdAt;
  final int urgency;
  @override
  final DateTime? deletedAt;
  final String code;
  final int serviceId;
  final List<int> employeeIds;
  final List<int> scenarioIds;
  @override
  String get name => title;
  @override
  DateTime get date => eventDate;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'title': title,
    'code': code,
    'type': type.name,
    'status': status.name,
    'serviceId': serviceId,
    'employeeIds': employeeIds,
    'scenarioIds': scenarioIds,
    'eventDate': eventDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'urgency': urgency,
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory AlibiRequest.fromJson(Map<String, dynamic> json) => AlibiRequest(
    id: readInt(json['id']),
    clientId: readInt(json['clientId'] ?? readMap(json['client'])['id']),
    title: readString(json['title']),
    code: readString(json['code']),
    serviceId: readInt(json['serviceId'] ?? readMap(json['service'])['id'], 1),
    type:
        RequestType.values
            .where((value) => value.name == json['type'])
            .firstOrNull ??
        RequestType.lateForWork,
    status:
        RequestStatus.values
            .where((value) => value.name == json['status'])
            .firstOrNull ??
        RequestStatus.newRequest,
    employeeIds: readIds(
      json['employeeIds'] ??
          (json['employees'] is List
              ? (json['employees'] as List)
                    .map((item) => readMap(item)['id'])
                    .toList()
              : null),
    ),
    scenarioIds: readIds(
      json['scenarioIds'] ??
          (json['scenarios'] is List
              ? (json['scenarios'] as List)
                    .map((item) => readMap(item)['id'])
                    .toList()
              : null),
    ),
    eventDate: readDate(json['eventDate']),
    createdAt: readDate(json['createdAt']),
    urgency: readInt(json['urgency'], 1),
    deletedAt: readOptionalDate(json['deletedAt']),
  );

  @override
  bool get isDeleted => deletedAt != null;

  AlibiRequest copyWith({
    int? clientId,
    String? title,
    RequestType? type,
    RequestStatus? status,
    DateTime? eventDate,
    DateTime? createdAt,
    int? urgency,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? code,
    int? serviceId,
    List<int>? employeeIds,
    List<int>? scenarioIds,
  }) {
    return AlibiRequest(
      id: id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt ?? this.createdAt,
      urgency: urgency ?? this.urgency,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      code: code ?? this.code,
      serviceId: serviceId ?? this.serviceId,
      employeeIds: employeeIds ?? this.employeeIds,
      scenarioIds: scenarioIds ?? this.scenarioIds,
    );
  }
}
