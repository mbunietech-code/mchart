import 'package:flutter_test/flutter_test.dart';
import 'package:mchart/src/models/enums.dart';

void main() {
  test('task status transitions are enforced', () {
    expect(TaskStatus.assigned.wire, 'assigned');
    expect(TaskStatus.inProgress.wire, 'in_progress');
    expect(TaskStatus.from('in_progress'), TaskStatus.inProgress);
  });

  test('user role hierarchy', () {
    expect(UserRole.admin.isManagerOrAdmin, isTrue);
    expect(UserRole.staff.isManagerOrAdmin, isFalse);
  });
}
