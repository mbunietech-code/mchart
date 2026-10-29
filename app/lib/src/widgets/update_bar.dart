import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_updater.dart';

/// Strip above every screen while a newer release is waiting.
class UpdateBar extends ConsumerWidget {
  const UpdateBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdaterProvider);
    if (state is! UpdateAvailable) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final progress = state.progress;
    final text = progress != null
        ? 'Downloading MChart ${state.release.version}… ${(progress * 100).round()}%'
        : state.error ?? 'MChart ${state.release.version} is available.';

    return Material(
      color: scheme.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(Icons.system_update, color: scheme.onPrimary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onPrimary),
                ),
              ),
              if (progress == null)
                TextButton(
                  onPressed: () =>
                      ref.read(appUpdaterProvider.notifier).install(),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimary,
                  ),
                  child: const Text('Update'),
                )
              else
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress,
                    color: scheme.onPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
