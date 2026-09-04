import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/paginated.dart';
import '../../models/user.dart';

class DirectoryRepository {
  DirectoryRepository(this._api);
  final ApiClient _api;

  Future<Paginated<User>> users({
    String? search,
    int? departmentId,
    String? role,
    String? status,
    int page = 1,
    int perPage = 25,
  }) async {
    final json = await _api.get<Map<String, dynamic>>('/users', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (departmentId != null) 'department_id': departmentId,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      'page': page,
      'per_page': perPage,
    });
    return Paginated.fromJson(json, User.fromJson);
  }

  Future<List<Department>> departments() async {
    final json = await _api.get<Map<String, dynamic>>('/departments');
    return Paginated.listOf(json, Department.fromJson);
  }

  Future<User> createUser(Map<String, dynamic> body) async {
    final json = await _api.post<Map<String, dynamic>>('/users', data: body);
    return User.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<User> updateUser(int id, Map<String, dynamic> body) async {
    final json = await _api.patch<Map<String, dynamic>>('/users/$id', data: body);
    return User.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> deactivateUser(int id) => _api.delete('/users/$id');

  Future<Department> createDepartment(Map<String, dynamic> body) async {
    final json = await _api.post<Map<String, dynamic>>('/departments', data: body);
    return Department.fromJson(json['data'] as Map<String, dynamic>);
  }
}

final directoryRepositoryProvider =
    Provider((ref) => DirectoryRepository(ref.watch(apiClientProvider)));

final departmentsProvider = FutureProvider<List<Department>>((ref) {
  return ref.watch(directoryRepositoryProvider).departments();
});

class UserQuery {
  const UserQuery({this.search = '', this.departmentId, this.role, this.status, this.page = 1});
  final String search;
  final int? departmentId;
  final String? role;
  final String? status;
  final int page;

  UserQuery copyWith({
    String? search,
    Object? departmentId = _sentinel,
    Object? role = _sentinel,
    Object? status = _sentinel,
    int? page,
  }) =>
      UserQuery(
        search: search ?? this.search,
        departmentId: departmentId == _sentinel ? this.departmentId : departmentId as int?,
        role: role == _sentinel ? this.role : role as String?,
        status: status == _sentinel ? this.status : status as String?,
        page: page ?? this.page,
      );

  static const _sentinel = Object();
}

final userQueryProvider = StateProvider<UserQuery>((ref) => const UserQuery());

final usersProvider = FutureProvider<Paginated<User>>((ref) {
  final q = ref.watch(userQueryProvider);
  return ref.watch(directoryRepositoryProvider).users(
        search: q.search,
        departmentId: q.departmentId,
        role: q.role,
        status: q.status,
        page: q.page,
      );
});
