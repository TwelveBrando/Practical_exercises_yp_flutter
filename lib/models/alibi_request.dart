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

class AlibiRequest {
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
  });

  final int id;
  final int clientId;
  final String title;
  final RequestType type;
  final RequestStatus status;
  final DateTime eventDate;
  final DateTime createdAt;
  final int urgency;
  final DateTime? deletedAt;

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
    );
  }
}
