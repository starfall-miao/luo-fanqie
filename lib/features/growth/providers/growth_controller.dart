import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/key_value_storage.dart';
import '../../../core/utils/date_utils.dart';
import '../models/growth_item.dart';

class GrowthController extends ChangeNotifier {
  GrowthController(this._storage, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    final raw = _storage.read(_storageKey);
    if (raw != null) _items = _decode(raw);
  }

  static const _storageKey = 'luo_fanqie.growth.v1';

  final KeyValueStorage _storage;
  final DateTime Function() _now;
  List<GrowthItem> _items = <GrowthItem>[];

  List<GrowthItem> get items => List<GrowthItem>.unmodifiable(_items);

  List<GrowthItem> get habits =>
      _items.where((item) => item.isHabit).toList(growable: false);

  List<GrowthItem> get plans =>
      _items.where((item) => !item.isHabit).toList(growable: false);

  int get todayHabits => habits.length;
  int get todayChecked => habits.where((item) => item.checkedToday).length;

  void add(GrowthItem item) {
    _items = [item, ..._items];
    _commit();
  }

  void remove(String id) {
    _items = _items.where((item) => item.id != id).toList(growable: false);
    _commit();
  }

  void checkInHabit(String id) {
    final item = _items.firstWhere(
      (value) => value.id == id,
      orElse: () => _items.first,
    );
    if (!item.isHabit) return;
    final today = dateKey(_now());
    if (item.lastCheckInDate == today) return;
    final yesterday = dateKey(addDays(_now(), -1));
    final nextStreak = item.lastCheckInDate == yesterday ? item.streak + 1 : 1;
    _items = [
      for (final value in _items)
        if (value.id == id)
          value.copyWith(
            streak: nextStreak,
            totalCheckIns: value.totalCheckIns + 1,
            lastCheckInDate: today,
            progress: value.progress + 1,
          )
        else
          value,
    ];
    _commit();
  }

  void addProgress(String id, double amount) {
    _items = [
      for (final value in _items)
        if (value.id == id)
          value.copyWith(
            progress: (value.progress + amount).clamp(
              0,
              value.target.toDouble(),
            ),
          )
        else
          value,
    ];
    _commit();
  }

  void _commit() {
    notifyListeners();
    unawaited(
      _storage.write(
        _storageKey,
        jsonEncode(_items.map((item) => item.toJson()).toList()),
      ),
    );
  }

  List<GrowthItem> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <GrowthItem>[];
      return decoded
          .whereType<Map>()
          .map((item) => GrowthItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return <GrowthItem>[];
    }
  }
}
