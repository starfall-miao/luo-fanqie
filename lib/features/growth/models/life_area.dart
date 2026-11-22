class LifeArea {
  const LifeArea({
    required this.id,
    required this.name,
    this.note = '',
    this.colorIndex = 0,
  });

  final String id;
  final String name;
  final String note;
  final int colorIndex;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'note': note,
    'colorIndex': colorIndex,
  };

  factory LifeArea.fromJson(Map<String, dynamic> json) => LifeArea(
    id: json['id'] as String? ?? 'area-${json['name']}',
    name: json['name'] as String? ?? '成长',
    note: json['note'] as String? ?? '',
    colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
  );
}
