import 'package:flutter/foundation.dart';
import '../models/alibi_request.dart';
import '../models/client.dart';
import '../models/client_query.dart';
import '../models/page_result.dart';
import '../models/request_query.dart';
import '../repositories/client_repository.dart';
import '../repositories/request_repository.dart';

enum LoadStatus { idle, loading, success, error }

class ClientListNotifier extends ChangeNotifier {
  ClientListNotifier(this._repository);
  final ClientRepository _repository;
  ClientQuery _query = const ClientQuery();
  PageResult<Client> _result = PageResult<Client>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  ClientQuery get query => _query;
  PageResult<Client> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _result = await _repository.find(_query);
      _status = LoadStatus.success;
    } catch (error) {
      _error = 'Не удалось загрузить клиентов: $error';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyQuery(ClientQuery query) async {
    _query = query;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    await _repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
  }

  Future<void> softDelete(int id) async {
    await _repository.softDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await _repository.hardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(int id) async {
    await _repository.restore(id);
    await load();
  }

  Future<Client?> findById(int id) => _repository.findById(id);
}

class RequestListNotifier extends ChangeNotifier {
  RequestListNotifier(this._repository);
  final RequestRepository _repository;
  RequestQuery _query = const RequestQuery();
  PageResult<AlibiRequest> _result = PageResult<AlibiRequest>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  RequestQuery get query => _query;
  PageResult<AlibiRequest> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _result = await _repository.find(_query);
      _status = LoadStatus.success;
    } catch (error) {
      _error = 'Не удалось загрузить заявки: $error';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyQuery(RequestQuery query) async {
    _query = query;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    await _repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
  }

  Future<void> softDelete(int id) async {
    await _repository.softDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await _repository.hardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(int id) async {
    await _repository.restore(id);
    await load();
  }

  Future<AlibiRequest?> findById(int id) => _repository.findById(id);
}
