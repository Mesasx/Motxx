import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String formatDate(DateTime d, [String pattern = 'EEE d MMM']) {
    return DateFormat(pattern).format(d);
  }

  static String formatTime(DateTime d) {
    return DateFormat.Hm().format(d);
  }

  static DateTime startOfDay(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime endOfDay(DateTime d) {
    return DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int daysBetween(DateTime from, DateTime to) {
    final f = startOfDay(from);
    final t = startOfDay(to);
    return t.difference(f).inDays;
  }

  static List<DateTime> weekDays(DateTime reference) {
    final monday = reference.subtract(Duration(days: reference.weekday - 1));
    return List.generate(7, (i) => startOfDay(monday.add(Duration(days: i))));
  }

  static String dayName(int dayOfWeek) {
    const names = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return names[dayOfWeek];
  }
}
