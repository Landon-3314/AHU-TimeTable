class AcademicCredential {
  const AcademicCredential({
    required this.studentId,
    required this.password,
    required this.autoLoginEnabled,
  });

  final String studentId;
  final String password;
  final bool autoLoginEnabled;

  AcademicCredential copyWith({
    String? studentId,
    String? password,
    bool? autoLoginEnabled,
  }) {
    return AcademicCredential(
      studentId: studentId ?? this.studentId,
      password: password ?? this.password,
      autoLoginEnabled: autoLoginEnabled ?? this.autoLoginEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AcademicCredential &&
            other.studentId == studentId &&
            other.password == password &&
            other.autoLoginEnabled == autoLoginEnabled;
  }

  @override
  int get hashCode => Object.hash(studentId, password, autoLoginEnabled);

  @override
  String toString() {
    return 'AcademicCredential(studentId: $studentId, '
        'password: <redacted>, autoLoginEnabled: $autoLoginEnabled)';
  }
}
