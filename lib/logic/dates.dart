/// 날짜 도우미. 일기는 'YYYY-MM-DD' 문자열 키로 저장한다.

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime addDays(DateTime day, int n) => DateTime(day.year, day.month, day.day + n);

String two(int n) => n.toString().padLeft(2, '0');

/// `2026-09-29`
String dateKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// `2026-09-29` → DateTime. 잘못된 형식이면 null.
DateTime? parseKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return dateKey(d) == key ? d : null;
}

const weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

/// `09.29 화`
String shortDate(DateTime d) => '${two(d.month)}.${two(d.day)} ${weekdayKo[d.weekday - 1]}';

/// `2026.09.29 화`
String longDate(DateTime d) => '${d.year}.${two(d.month)}.${two(d.day)} ${weekdayKo[d.weekday - 1]}';

/// 사용자가 친 날짜를 해석한다. 오늘 기준으로:
/// `2026-09-28`, `2026.09.28`, `09.28`, `9/28`, `9-28`, `어제`, `yesterday`, `오늘`, `today`.
/// 연도를 생략하면 올해(미래면 작년)로 본다. 알아볼 수 없으면 null.
DateTime? parseDateArg(String raw, DateTime now) {
  final a = raw.trim().toLowerCase();
  final today = dayOf(now);
  switch (a) {
    case '오늘' || 'today':
      return today;
    case '어제' || 'yesterday':
      return addDays(today, -1);
    case '그제' || '그저께':
      return addDays(today, -2);
  }
  final full = RegExp(r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})$').firstMatch(a);
  if (full != null) {
    return _valid(int.parse(full[1]!), int.parse(full[2]!), int.parse(full[3]!));
  }
  final short = RegExp(r'^(\d{1,2})[-./](\d{1,2})$').firstMatch(a);
  if (short != null) {
    final m = int.parse(short[1]!);
    final d = int.parse(short[2]!);
    final thisYear = _valid(today.year, m, d);
    if (thisYear != null && !thisYear.isAfter(today)) return thisYear;
    return _valid(today.year - 1, m, d) ?? thisYear;
  }
  return null;
}

DateTime? _valid(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  return (dt.month == m && dt.day == d) ? dt : null;
}
