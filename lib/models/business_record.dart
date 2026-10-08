import 'agency_record.dart';
import 'json_readers.dart';

const contractStatuses = {
  'draft': 'Черновик',
  'signed': 'Подписан',
  'completed': 'Исполнен',
  'cancelled': 'Отменён',
};
const paymentStatuses = {'paid': 'Оплачен', 'refunded': 'Возвращён'};
const paymentMethods = {
  'cash': 'Наличные',
  'card': 'Банковская карта',
  'transfer': 'Перевод',
};

class BusinessRecord implements AgencyRecord {
  BusinessRecord(this.kind, Map<String, dynamic> json)
    : _values = {
        'id': readInt(json['id']),
        'name': readString(json['name']),
        'deletedAt': readOptionalDate(json['deletedAt'])?.toIso8601String(),
        if (kind == EntityKind.cards) ...{
          'clientId': readInt(json['clientId']),
          'number': readString(json['number']),
          'points': readInt(json['points']),
          'issuedAt': readDate(json['issuedAt']).toIso8601String(),
        },
        if (kind == EntityKind.contracts) ...{
          'requestId': readInt(json['requestId']),
          'code': readString(json['code']),
          'status': readString(json['status'], 'draft'),
          'discountPercent': readInt(json['discountPercent']),
          'amount': readInt(json['amount']),
          'pricing': readMap(json['pricing']),
          'createdAt': readDate(json['createdAt']).toIso8601String(),
        },
        if (kind == EntityKind.payments) ...{
          'contractId': readInt(json['contractId']),
          'amount': readInt(json['amount']),
          'method': readString(json['method'], 'card'),
          'status': readString(json['status'], 'paid'),
          'paidAt': readDate(json['paidAt']).toIso8601String(),
        },
      };
  final EntityKind kind;
  final Map<String, dynamic> _values;
  @override
  int get id => _values['id'] as int;
  @override
  String get name => _values['name'] as String;
  @override
  DateTime get date => readDate(
    _values[kind == EntityKind.cards
        ? 'issuedAt'
        : kind == EntityKind.payments
        ? 'paidAt'
        : 'createdAt'],
  );
  @override
  DateTime? get deletedAt => readOptionalDate(_values['deletedAt']);
  @override
  bool get isDeleted => deletedAt != null;
  @override
  Map<String, dynamic> toJson() => {..._values};
}
