import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/key_value_storage.dart';
import '../../../core/utils/date_utils.dart';
import '../models/growth_item.dart';
import '../models/life_area.dart';

class GrowthController extends ChangeNotifier {
  GrowthController(this._storage, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    final raw = _storage.read(_storageKey);
    if (raw != null) _items = _decode(raw);
    final areasRaw = _storage.read(_areasKey);
    if (areasRaw != null) {
      _areas = _decodeAreas(areasRaw);
    }
    if (_areas.isEmpty) {
      _areas = _defaultAreas();
      unawaited(_persistAreas());
    }
  }

  static const _storageKey = 'luo_fanqie.growth.v1';
  static const _areasKey = 'luo_fanqie.growth_areas.v1';

  final KeyValueStorage _storage;
  final DateTime Function() _now;
  List<GrowthItem> _items = <GrowthItem>[];
  List<LifeArea> _areas = <LifeArea>[];

  List<GrowthItem> get items => List<GrowthItem>.unmodifiable(_items);

  List<LifeArea> get areas => List<LifeArea>.unmodifiable(_areas);

  List<GrowthItem> itemsInArea(String area) =>
      _items.where((item) => item.area == area).toList(growable: false);

  int countInArea(String area) => itemsInArea(area).length;

  List<GrowthItem> get habits =>
      _items.where((item) => item.isHabit).toList(growable: false);

  List<GrowthItem> get plans =>
      _items.where((item) => !item.isHabit).toList(growable: false);

  int get todayHabits => habits.length;
  int get todayChecked => habits.where((item) => item.checkedOn(_now())).length;

  List<LifeArea> _defaultAreas() {
    return const [
      LifeArea(id: 'area-study', name: '学习', note: '知识与技能'),
      LifeArea(id: 'area-health', name: '健康', note: '身体与睡眠'),
      LifeArea(id: 'area-create', name: '创作', note: '表达与作品'),
      LifeArea(id: 'area-relation', name: '关系', note: '家人与朋友'),
      LifeArea(id: 'area-money', name: '财务', note: '收入与储蓄'),
    ];
  }

  void addArea(LifeArea area) {
    if (area.name.trim().isEmpty ||
        _areas.any((existing) => existing.name == area.name)) {
      return;
    }
    _areas = [..._areas, area];
    notifyListeners();
    unawaited(_persistAreas());
  }

  void removeArea(String id) {
    final area = _areas.firstWhere(
      (item) => item.id == id,
      orElse: () => _areas.first,
    );
    if (_areas.length <= 1) return;
    _areas = _areas.where((item) => item.id != id).toList(growable: false);
    // 不删除成长项目，把它们归到“未分类”。
    _items = [
      for (final item in _items)
        if (item.area == area.name) item.copyWith(area: '未分类') else item,
    ];
    notifyListeners();
    unawaited(_persistAreas());
    unawaited(_persistItems());
  }

  void ensureArea(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_areas.any((area) => area.name == trimmed)) return;
    addArea(
      LifeArea(
        id: 'area-${DateTime.now().microsecondsSinceEpoch}',
        name: trimmed,
        colorIndex: _areas.length,
      ),
    );
  }

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
    unawaited(_persistItems());
  }

  Future<void> _persistItems() => _storage.write(
    _storageKey,
    jsonEncode(_items.map((item) => item.toJson()).toList()),
  );

  Future<void> _persistAreas() => _storage.write(
    _areasKey,
    jsonEncode(_areas.map((area) => area.toJson()).toList()),
  );

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

  List<LifeArea> _decodeAreas(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <LifeArea>[];
      return decoded
          .whereType<Map>()
          .map((item) => LifeArea.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return <LifeArea>[];
    }
  }
}
