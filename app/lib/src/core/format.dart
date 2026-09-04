import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _time = DateFormat('h:mm a');
  static final _dayMonth = DateFormat('EEEE, d MMMM yyyy');
  static final _shortDate = DateFormat('d MMM');

  static String time(DateTime d) => _time.format(d);
  static String dayHeading(DateTime d) => _dayMonth.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);

  /// "sasa hivi", "dakika 5 zilizopita", "saa 2 zilizopita", "jana", "3 Jun".
  static String relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 45) return 'sasa hivi';
    if (diff.inMinutes < 60) return 'dakika ${diff.inMinutes} zilizopita';
    if (diff.inHours < 24) return 'saa ${diff.inHours} zilizopita';
    if (diff.inDays == 1) return 'jana';
    if (diff.inDays < 7) return 'siku ${diff.inDays} zilizopita';
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
    if (d == null) return 'Hakuna tarehe';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return 'Imepita kwa siku ${-days}';
    if (days == 0) return 'Leo';
    if (days == 1) return 'Kesho';
    return _shortDate.format(d);
  }
}
