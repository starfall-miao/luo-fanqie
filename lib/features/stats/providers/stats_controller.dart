import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/key_value_storage.dart';
import '../../../core/utils/date_utils.dart';
import '../models/focus_session.dart';

class StatsController extends ChangeNotifier {
  StatsController(this._storage, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    final raw = _storage.read(_storageKey);
    if (raw != null) _sessions = _decode(raw);
    _sort();
  }

  static const _storageKey = 'luo_fanqie.sessions.v1';

  final KeyValueStorage _storage;
  final DateTime Function() _now;
  List<FocusSession> _sessions = <FocusSession>[];

  List<FocusSession> get sessions => List<FocusSession>.unmodifiable(_sessions);

  int get totalMinutes =>
      _sessions.fold<int>(0, (sum, session) => sum + session.minutes);

  int get totalSessions => _sessions.length;

  int get todayMinutes => minutesOn(_now());

  int get todaySessions => sessionsOn(_now()).length;

  int get weekMinutes {
    final start = startOfWeek(_now());
    final end = addDays(start, 7);
    return _sessions
        .where((s) => !s.endedAt.isBefore(start) && s.endedAt.isBefore(end))
        .fold<int>(0, (sum, s) => sum + s.minutes);
  }

  int get weekSessions {
    final start = startOfWeek(_now());
    final end = addDays(start, 7);
    return _sessions
        .where((s) => !s.endedAt.isBefore(start) && s.endedAt.isBefore(end))
        .length;
  }

  /// 连续专注天数。如果今天还没有记录，则延续到昨天为止。
  int get streak {
    final days = _sessions.map((s) => dateKey(s.endedAt)).toSet();
    if (days.isEmpty) return 0;
    var cursor = startOfDay(_now());
    if (!days.contains(dateKey(cursor))) {
      cursor = addDays(cursor, -1);
      if (!days.contains(dateKey(cursor))) return 0;
    }
    var count = 0;
    while (days.contains(dateKey(cursor))) {
      count += 1;
      cursor = addDays(cursor, -1);
    }
    return count;
  }

  List<FocusSession> sessionsOn(DateTime date) {
    final key = dateKey(date);
    return _sessions
        .where((s) => dateKey(s.endedAt) == key)
        .toList(growable: false);
  }

  int minutesOn(DateTime date) =>
      sessionsOn(date).fold<int>(0, (sum, session) => sum + session.minutes);

  List<DayStat> lastNDays(int count, {DateTime? endDate}) {
    final end = startOfDay(endDate ?? _now());
    final totals = <String, DayStat>{};
    for (final session in _sessions) {
      final key = dateKey(session.endedAt);
      final day = startOfDay(session.endedAt);
      final existing = totals[key];
      totals[key] = DayStat(
        date: day,
        sessions: (existing?.sessions ?? 0) + 1,
        minutes: (existing?.minutes ?? 0) + session.minutes,
      );
    }
    return List<DayStat>.generate(count, (index) {
      final date = addDays(end, index - count + 1);
      return totals[dateKey(date)] ??
          DayStat(date: date, sessions: 0, minutes: 0);
    });
  }

  /// 本周一至周日。
  List<DayStat> currentWeek() {
    final start = startOfWeek(_now());
    return List<DayStat>.generate(7, (index) {
      final date = addDays(start, index);
      final sessions = sessionsOn(date);
      return DayStat(
        date: date,
        sessions: sessions.length,
        minutes: sessions.fold<int>(0, (sum, s) => sum + s.minutes),
      );
    });
  }

  List<FocusSession> recent({int limit = 5}) =>
      _sessions.take(limit).toList(growable: false);

  /// 以指定结束日为终点，取最近 [weeks] 个完整自然周（周一开始）。
  List<DayStat> heatmap({int weeks = 12, DateTime? endDate}) {
    final lastDay = startOfDay(endDate ?? _now());
    final endWeekStart = startOfWeek(lastDay);
    final start = addDays(endWeekStart, -(weeks - 1) * 7);
    final totals = <String, DayStat>{};
    for (final session in _sessions) {
      final key = dateKey(session.endedAt);
      final existing = totals[key];
      totals[key] = DayStat(
        date: startOfDay(session.endedAt),
        sessions: (existing?.sessions ?? 0) + 1,
        minutes: (existing?.minutes ?? 0) + session.minutes,
      );
    }
    return List<DayStat>.generate(weeks * 7, (index) {
      final date = addDays(start, index);
      return totals[dateKey(date)] ??
          DayStat(date: date, sessions: 0, minutes: 0);
    });
  }

  /// 记录一次专注。[FocusSession.id] 用来幂等去重，避免恢复计时时重复计数。
  /// 返回 true 表示这是新记录；重复 ID 会被忽略并返回 false。
  bool record(FocusSession session) {
    if (_sessions.any((existing) => existing.id == session.id)) return false;
    _sessions = [session, ..._sessions];
    _sort();
    notifyListeners();
    unawaited(_persist());
    return true;
  }

  /// 写入同步合并后的记录：按 id 去重并保留全部历史。
  void applyMergedSessions(Iterable<FocusSession> incoming) {
    final byId = <String, FocusSession>{
      for (final session in _sessions) session.id: session,
    };
    for (final session in incoming) {
      byId.putIfAbsent(session.id, () => session);
    }
    _sessions = byId.values.toList();
    _sort();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() => _storage.write(
    _storageKey,
    jsonEncode(_sessions.map((s) => s.toJson()).toList()),
  );

  void clearAll() {
    _sessions = <FocusSession>[];
    notifyListeners();
    unawaited(_storage.delete(_storageKey));
  }

  void _sort() {
    _sessions.sort((a, b) => b.endedAt.compareTo(a.endedAt));
  }

  List<FocusSession> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <FocusSession>[];
      return decoded
          .whereType<Map>()
          .map((map) => FocusSession.fromJson(Map<String, dynamic>.from(map)))
          .where((session) => session.minutes > 0)
          .toList();
    } catch (_) {
      return <FocusSession>[];
    }
  }
}
