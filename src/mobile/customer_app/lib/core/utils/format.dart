import 'package:intl/intl.dart';

/// Shared display formatters. Use these everywhere instead of inline DateFormat
/// / string interpolation so money + dates read consistently across screens.
abstract final class Fmt {
  static final _money = NumberFormat.currency(locale: 'en_GB', symbol: '£');
  static final _date = DateFormat('EEE d MMM');
  static final _time = DateFormat('HH:mm');
  static final _dateTime = DateFormat('EEE d MMM, HH:mm');

  static String money(num? value) => _money.format(value ?? 0);
  static String date(DateTime d) => _date.format(d);
  static String time(DateTime d) => _time.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);

  /// "in 5 min" / "2 min ago" style relative label.
  static String relative(DateTime d) {
    final diff = d.difference(DateTime.now());
    final mins = diff.inMinutes;
    if (mins.abs() < 1) return 'now';
    if (mins > 0) {
      if (mins < 60) return 'in $mins min';
      return 'in ${diff.inHours}h';
    }
    final ago = mins.abs();
    if (ago < 60) return '$ago min ago';
    return '${(-diff.inHours)}h ago';
  }
}
