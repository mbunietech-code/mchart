import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _time = DateFormat('h:mm a');
  static final _dayMonth = DateFormat('EEEE, d MMMM yyyy');
  static final _shortDate = DateFormat('d MMM');

  static String time(DateTime d) => _time.format(d);
  static String dayHeading(DateTime d) => _dayMonth.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);

  /// "just now", "5 min ago", "2 hr ago", "yesterday", "3 Jun".
  static String relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return _shortDate.format(d);
  }

  static String fileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String duration(int? seconds) {
    if (seconds == null) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String deadline(DateTime? d) {
    if (d == null) return 'No deadline';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return _shortDate.format(d);
  }
}
