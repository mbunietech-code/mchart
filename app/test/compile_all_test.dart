// Imports every library so `flutter test` becomes a full-tree compile check.
// (The analysis server is unstable on this machine.)
// ignore_for_file: unused_import
import 'package:flutter_test/flutter_test.dart';
import 'package:mchart/main.dart';
import 'package:mchart/src/app/app.dart';
import 'package:mchart/src/app/app_router.dart';
import 'package:mchart/src/app/app_shell.dart';
import 'package:mchart/src/core/api_client.dart';
import 'package:mchart/src/core/api_exception.dart';
import 'package:mchart/src/core/env.dart';
import 'package:mchart/src/core/format.dart';
import 'package:mchart/src/core/providers.dart';
import 'package:mchart/src/core/realtime.dart';
import 'package:mchart/src/core/token_store.dart';
import 'package:mchart/src/features/auth/auth_controller.dart';
import 'package:mchart/src/features/auth/login_screen.dart';
import 'package:mchart/src/features/chat/chat_repository.dart';
import 'package:mchart/src/features/chat/chat_screen.dart';
import 'package:mchart/src/features/chat/message_thread_controller.dart';
import 'package:mchart/src/features/dashboard/dashboard_repository.dart';
import 'package:mchart/src/features/dashboard/dashboard_screen.dart';
import 'package:mchart/src/features/directory/directory_repository.dart';
import 'package:mchart/src/features/notifications/notifications_controller.dart';
import 'package:mchart/src/features/notifications/notifications_panel.dart';
import 'package:mchart/src/features/settings/settings_screen.dart';
import 'package:mchart/src/features/settings/user_form.dart';
import 'package:mchart/src/features/tasks/task_detail_screen.dart';
import 'package:mchart/src/features/tasks/task_form.dart';
import 'package:mchart/src/features/tasks/task_repository.dart';
import 'package:mchart/src/features/tasks/tasks_screen.dart';
import 'package:mchart/src/models/app_notification.dart';
import 'package:mchart/src/models/dashboard.dart';
import 'package:mchart/src/models/enums.dart';
import 'package:mchart/src/models/message.dart';
import 'package:mchart/src/models/paginated.dart';
import 'package:mchart/src/models/task.dart';
import 'package:mchart/src/models/user.dart';
import 'package:mchart/src/theme/app_color.dart';
import 'package:mchart/src/theme/app_spacing.dart';
import 'package:mchart/src/theme/app_theme.dart';
import 'package:mchart/src/theme/app_typography.dart';
import 'package:mchart/src/widgets/avatar.dart';
import 'package:mchart/src/widgets/mchart_logo.dart';
import 'package:mchart/src/widgets/page_header.dart';
import 'package:mchart/src/widgets/pills.dart';
import 'package:mchart/src/widgets/primitives.dart';
import 'package:mchart/src/widgets/stat_card.dart';

void main() {
  test('all libraries compile', () {
    expect(1, 1);
  });
}
