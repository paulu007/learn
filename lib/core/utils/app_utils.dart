import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a unique id for local rows.
String newId() => _uuid.v4();

/// Milliseconds since epoch (UTC) for storage.
int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Local calendar day as `yyyy-MM-dd`.
String dayKey([DateTime? date]) {
  final d = date ?? DateTime.now();
  return DateFormat('yyyy-MM-dd').format(d);
}

/// Whole days from [from] until today (calendar days, local time).
int daysSince(DateTime from) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(from.year, from.month, from.day);
  return a.difference(b).inDays;
}

/// Adds [days] calendar days to a [dayKey] string.
String addDays(String key, int days) {
  final d = DateFormat('yyyy-MM-dd').parse(key);
  return dayKey(d.add(Duration(days: days)));
}

/// Greeting shown on the home screen based on time of day.
String dayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning!';
  if (hour < 18) return 'Good afternoon!';
  return 'Good evening!';
}
