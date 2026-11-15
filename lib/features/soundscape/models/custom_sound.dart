class CustomSound {
  const CustomSound({
    required this.id,
    required this.name,
    required this.fileName,
    this.addedAt,
  });

  final String id;
  final String name;
  final String fileName;
  final DateTime? addedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'fileName': fileName,
    'addedAt': addedAt?.toIso8601String(),
  };

  factory CustomSound.fromJson(Map<String, dynamic> json) => CustomSound(
    id: json['id'] as String? ?? 'custom-${json['fileName']}',
    name: json['name'] as String? ?? '自定义音频',
    fileName: json['fileName'] as String? ?? '',
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
  );
}
