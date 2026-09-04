import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (kDebugMode) {
          debugPrint('Flutter error: ${details.exceptionAsString()}\n${details.stack}');
        }
      };
      runApp(const ProviderScope(child: MChartApp()));
    },
    (error, stack) => debugPrint('Uncaught: $error\n$stack'),
  );
}
