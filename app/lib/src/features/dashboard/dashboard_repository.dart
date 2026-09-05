import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/dashboard.dart';

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<DashboardSummary> summary({int? departmentId}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/dashboard/summary',
      query: {if (departmentId != null) 'department_id': departmentId},
    );
    return DashboardSummary.fromJson(json);
  }

  Future<List<ActivityEvent>> activity({int limit = 30}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/dashboard/activity',
      query: {'limit': limit},
    );
    return (json['data'] as List? ?? const [])
        .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final dashboardRepositoryProvider = Provider(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);

final dashboardDepartmentProvider = StateProvider<int?>((ref) => null);

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  return ref
      .watch(dashboardRepositoryProvider)
      .summary(departmentId: ref.watch(dashboardDepartmentProvider));
});

final dashboardActivityProvider = FutureProvider<List<ActivityEvent>>((ref) {
  return ref.watch(dashboardRepositoryProvider).activity();
});
