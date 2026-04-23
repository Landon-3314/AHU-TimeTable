class Semester {
  const Semester({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isInitialized,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool isInitialized;

  Semester copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    bool? isInitialized,
  }) {
    return Semester(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isInitialized': isInitialized,
    };
  }

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: (json['id'] as String?) ?? createId(),
      name: (json['name'] as String?) ?? '第 1 学期',
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      isInitialized: (json['isInitialized'] as bool?) ?? false,
    );
  }

  static String createId() {
    return 'semester-${DateTime.now().microsecondsSinceEpoch}';
  }
}
